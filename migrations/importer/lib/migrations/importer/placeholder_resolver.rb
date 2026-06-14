# frozen_string_literal: true

module Migrations
  module Importer
    # Import-time counterpart of the converter's `EmbedBuffer`: it rewrites the
    # opaque placeholder tokens left in `post.raw` back into real Markdown, now that
    # the `original_id -> discourse_id` maps exist.
    #
    # This is the v2 replacement for the v1 `raw_with_placeholders_interpolated`
    # helper. Two things change, both deliberate:
    #
    #   * **Load once, substitute many.** All linkage rows for a batch of posts are
    #     read up front (one query per kind), then every body is rewritten purely in
    #     memory. The v1 version ran several SQL queries *inside* the per-post
    #     substitution loop; here there is no SQL on the substitution path.
    #   * **Plain `gsub`, no padding hacks.** Because `Migrations::Placeholder`
    #     brackets every token in a Private Use Area delimiter, a token can never
    #     collide with user content, so the v1 link whitespace-padding regex dance is
    #     gone — each token is replaced with a bare `String#gsub`.
    #
    # ## The `maps` collaborator
    #
    # Rendering needs the already-built import maps. They are injected as a single
    # duck-typed `maps` object so the resolver stays pure (no DB access while
    # substituting) and unit-testable. It must respond to:
    #
    #   * `user(original_id)`          => `{ username:, name: }` or `nil`
    #   * `group_name(original_id)`    => `String` or `nil`
    #   * `post(original_id)`          => `{ topic_id:, post_number: }` or `nil`
    #   * `topic_id(original_id)`      => discourse topic id or `nil`
    #   * `upload_markdown(original_id)` => resolved `upload://…` Markdown or `nil`
    #   * `poll_markdown(original_id)` => the poll's rendered Markdown or `nil`
    #   * `event_markdown(original_id)` => the event's rendered Markdown or `nil`
    #   * `base_url`                   => the destination site's base URL
    #
    # Lookups that return `nil` fall back to the source value (or an empty string),
    # mirroring the v1 behaviour.
    class PlaceholderResolver
      # Maps each typed collection to its IntermediateDB linkage table.
      TABLES = {
        quote: "post_quotes",
        link: "post_links",
        mention: "post_mentions",
        poll: "post_polls",
        event: "post_events",
        upload: "post_uploads",
      }.freeze
      private_constant :TABLES

      # @param intermediate_db [Migrations::Database::Connection] read-only access to
      #   the IntermediateDB linkage tables.
      # @param maps [#user, #group_name, #post, #topic_id, #upload_markdown,
      #   #poll_markdown, #event_markdown, #base_url] the built import maps.
      def initialize(intermediate_db, maps)
        @intermediate_db = intermediate_db
        @maps = maps
      end

      # Resolves the placeholder tokens in a batch of posts.
      #
      # @param posts [Array<Hash>] each with `:id` (the source post original_id) and
      #   `:raw`.
      # @return [Hash{Object => String}] source post id => resolved raw.
      def resolve_all(posts)
        linkages = load_linkages(posts.map { |post| post[:id] })

        posts.each_with_object({}) do |post, result|
          result[post[:id]] = substitute(post[:raw], linkages[post[:id]])
        end
      end

      # Resolves the placeholder tokens in a single raw body against its already
      # loaded linkage rows. Used by `resolve_all`; exposed for callers that load
      # linkage rows themselves.
      #
      # @param raw [String, nil]
      # @param linkage_rows [Array<Hash>, nil] rows tagged with `:_kind`.
      # @return [String, nil]
      def substitute(raw, linkage_rows)
        return raw if raw.nil? || linkage_rows.nil? || linkage_rows.empty?

        result = raw.dup
        linkage_rows.each { |row| result = result.gsub(row[:placeholder], render(row)) }
        result
      end

      private

      # One query per kind, grouped by post id. This is the only place that touches
      # the database; the substitution path below is pure.
      def load_linkages(post_ids)
        buckets = Hash.new { |hash, key| hash[key] = [] }
        return buckets if post_ids.empty?

        bind_params = (["?"] * post_ids.size).join(", ")

        TABLES.each do |kind, table|
          sql = "SELECT * FROM #{table} WHERE post_id IN (#{bind_params})"
          @intermediate_db.query(sql, *post_ids) do |row|
            row[:_kind] = kind
            buckets[row[:post_id]] << row
          end
        end

        buckets
      end

      def render(row)
        case row[:_kind]
        when :quote
          render_quote(row)
        when :link
          render_link(row)
        when :mention
          render_mention(row)
        when :poll
          @maps.poll_markdown(row[:poll_id]).to_s
        when :event
          @maps.event_markdown(row[:event_id]).to_s
        when :upload
          @maps.upload_markdown(row[:upload_id]).to_s
        else
          raise ArgumentError, "Unknown placeholder kind: #{row[:_kind].inspect}"
        end
      end

      def render_quote(row)
        user = row[:quoted_user_id] ? @maps.user(row[:quoted_user_id]) : nil
        username = user&.fetch(:username, nil) || row[:quoted_username]
        name = user&.fetch(:name, nil)

        if row[:quoted_post_id] && (post = @maps.post(row[:quoted_post_id]))
          topic_id = post[:topic_id]
          post_number = post[:post_number]
        end

        return "[quote]" if username.blank? && name.blank?

        parts = []
        parts << (name.presence || username)
        parts << "post:#{post_number}" if post_number.present?
        parts << "topic:#{topic_id}" if topic_id.present?
        parts << "username:#{username}" if username.present? && name.present?

        "[quote=\"#{parts.join(", ")}\"]"
      end

      def render_link(row)
        url =
          if row[:target_topic_id]
            (topic_id = @maps.topic_id(row[:target_topic_id])) ? topic_url(topic_id) : row[:url]
          elsif row[:target_post_id] && (post = @maps.post(row[:target_post_id]))
            post[:topic_id] && post[:post_number] ? post_url(post) : row[:url]
          else
            row[:url]
          end

        row[:text] ? "[#{row[:text]}](#{url})" : url.to_s
      end

      def render_mention(row)
        name =
          case row[:mention_type]
          when "here"
            "here"
          when "all"
            "all"
          when "group"
            @maps.group_name(row[:target_id]) || row[:name]
          else
            @maps.user(row[:target_id])&.fetch(:username, nil) || row[:name]
          end

        name.present? ? " @#{name} " : ""
      end

      def topic_url(topic_id)
        "#{@maps.base_url}/t/#{topic_id}"
      end

      def post_url(post)
        "#{@maps.base_url}/t/#{post[:topic_id]}/#{post[:post_number]}"
      end
    end
  end
end
