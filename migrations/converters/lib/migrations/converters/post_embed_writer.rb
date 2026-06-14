# frozen_string_literal: true

module Migrations
  module Converters
    # Drains an {EmbedBuffer}'s typed descriptors into the matching IntermediateDB
    # `post_*` linkage tables, once the Posts step has written the post itself.
    #
    # Every converter that defers post embeds needs exactly this, and it is fully
    # converter-agnostic: the buffer's six collections map one-to-one onto the six
    # linkage tables, and each descriptor hash is already keyed to its table's
    # columns (minus `post_id`), so it splats straight into `create`.
    #
    # The drain lives here rather than on {EmbedBuffer} on purpose: the buffer's
    # contract is "no DB or id-map access", which is what keeps a processor's
    # `process` a pure function safe to run on forked workers. Touching the
    # IntermediateDB is a separate, processor-side concern.
    module PostEmbedWriter
      IntermediateDB = Database::IntermediateDB

      # @param post_id [Integer] the source `original_id` of the post the embeds
      #   were extracted from.
      # @param embeds [EmbedBuffer] the post's drained embed sink.
      # @return [void]
      def self.write(post_id, embeds)
        embeds.uploads.each { |embed| IntermediateDB::PostUpload.create(post_id:, **embed) }
        embeds.quotes.each { |embed| IntermediateDB::PostQuote.create(post_id:, **embed) }
        embeds.mentions.each { |embed| IntermediateDB::PostMention.create(post_id:, **embed) }
        embeds.links.each { |embed| IntermediateDB::PostLink.create(post_id:, **embed) }
        embeds.polls.each { |embed| IntermediateDB::PostPoll.create(post_id:, **embed) }
        embeds.events.each { |embed| IntermediateDB::PostEvent.create(post_id:, **embed) }
        nil
      end
    end
  end
end
