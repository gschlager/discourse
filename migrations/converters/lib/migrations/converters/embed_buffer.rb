# frozen_string_literal: true

module Migrations
  module Converters
    # Pure, per-post accumulator for deferred embeds discovered while a post body
    # is converted to Markdown.
    #
    # The cooker calls back here for every fragment it cannot finalize at convert
    # time — a quote, link, mention, poll, event or upload — because rendering it
    # needs the `original_id -> discourse_id` maps that only exist at import time.
    # `EmbedBuffer` mints a collision-proof token via `Migrations::Placeholder`,
    # records a typed descriptor carrying that token, and returns the token for the
    # cooker to splice into the raw in place of the fragment.
    #
    # After the body is converted, the Posts step writes the post and then drains
    # each typed collection into its IntermediateDB linkage table, e.g.
    #
    #     buffer.quotes.each { |q| IntermediateDB::PostQuote.create(post_id:, **q) }
    #
    # The descriptors are plain hashes whose keys match the linkage table columns
    # (minus `post_id`), so they splat straight into `create`. Keeping the buffer
    # free of any DB or id-map access is what lets `process_item` stay a pure
    # function of `(item, static config)`, safe to run on the converter's worker
    # threads and reusable across every converter.
    class EmbedBuffer
      attr_reader :quotes, :links, :mentions, :polls, :events, :uploads

      # @param placeholder [Migrations::Placeholder] the token minter; a fresh
      #   instance (with its own random nonce) is used per buffer by default.
      def initialize(placeholder: Migrations::Placeholder.new)
        @placeholder = placeholder
        @quotes = []
        @links = []
        @mentions = []
        @polls = []
        @events = []
        @uploads = []
      end

      # @return [String] the token to splice into the raw in place of the quote.
      def quote(quoted_post_id: nil, quoted_user_id: nil, quoted_username: nil)
        record(@quotes, :quote, quoted_post_id:, quoted_user_id:, quoted_username:)
      end

      # @return [String] the token to splice into the raw in place of the link.
      def link(url: nil, text: nil, target_topic_id: nil, target_post_id: nil)
        record(@links, :link, url:, text:, target_topic_id:, target_post_id:)
      end

      # @return [String] the token to splice into the raw in place of the mention.
      def mention(mention_type: nil, target_id: nil, name: nil)
        record(@mentions, :mention, mention_type:, target_id:, name:)
      end

      # @return [String] the token to splice into the raw in place of the poll.
      def poll(poll_id: nil)
        record(@polls, :poll, poll_id:)
      end

      # @return [String] the token to splice into the raw in place of the event.
      def event(event_id: nil)
        record(@events, :event, event_id:)
      end

      # @return [String] the token to splice into the raw in place of the upload.
      def upload(upload_id: nil)
        record(@uploads, :upload, upload_id:)
      end

      # Every token this buffer has minted, across all kinds, in mint order. Mirrors
      # what should be present in the post raw — handy for asserting the contract.
      #
      # @return [Array<String>]
      def placeholders
        descriptors.map { |descriptor| descriptor[:placeholder] }
      end

      # @return [Boolean] whether the post had no deferred embeds.
      def empty?
        descriptors.empty?
      end

      private

      def descriptors
        @quotes + @links + @mentions + @polls + @events + @uploads
      end

      def record(collection, kind, **fields)
        placeholder = @placeholder.mint(kind)
        collection << { placeholder:, **fields }
        placeholder
      end
    end
  end
end
