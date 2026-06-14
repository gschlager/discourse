# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # The phpBB source. A SQL-family Source that exposes each entity as a count
      # and a lazy, type-normalized stream of plain row-hashes — the stable
      # contract every step reads. The retrieval mechanism (mysql2 / pg, the
      # dialect, capability probes for version drift) lives entirely here, in the
      # parent process; workers never hold a handle to it.
      #
      # TODO (fill-in):
      #   * Build on the SQL Source toolkit (`source/sql/{connection,dialect,
      #     introspector}`) once it is extracted.
      #   * Pick the adapter + dialect from `settings[:type]`; this replaces the
      #     legacy `Database3` / `Database3Postgres` version×dialect class chain.
      #   * Detect `Capabilities` once, and resolve the handful of version-variable
      #     columns through named seams (see `capabilities.rb`).
      #   * Port `count_*` / `fetch_*` from the legacy converter's `Database3`
      #     family, emitting `dialect`-neutral SQL and type-normalized rows.
      class Source
        # Entities exposed to the steps. Each gets `count_<entity>` (Integer) and
        # `fetch_<entity>` (lazy Enumerator of normalized row-hashes).
        ENTITIES = %i[
          users
          anonymous_users
          groups
          group_members
          categories
          topics
          posts
          messages
          polls
          poll_options
          poll_votes
        ].freeze

        # @param settings [Hash] the `source_db` settings block.
        # @return [Source]
        def self.create(_settings)
          raise NotImplementedError, "phpBB Source is not implemented yet"
        end

        ENTITIES.each do |entity|
          define_method(:"count_#{entity}") { raise NotImplementedError }
          define_method(:"fetch_#{entity}") { raise NotImplementedError }
        end

        # Static phpBB config read once at setup (smilies path, attachment path,
        # avatar paths, version, ...), passed to processors as `phpbb_config`.
        def config
          raise NotImplementedError
        end
      end
    end
  end
end
