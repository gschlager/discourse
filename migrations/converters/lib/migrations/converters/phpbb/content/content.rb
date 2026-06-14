# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # Converts a phpBB post body to Discourse Markdown. phpBB owns only two
      # things on top of the shared engine: per-row format selection and a thin
      # legacy pre-clean. The conversion itself goes through
      # `Migrations::Converters::Content` (the Markbridge wrapper), which also
      # records deferred embeds onto the `on_embed` sink.
      #
      # Format is sniffed per row, not inferred from the phpBB version: s9e
      # TextFormatter stores its parsed form rooted at `<r>` (rich) or `<t>`
      # (plain); anything else is legacy BBCode. This is robust to mixed content
      # left behind by an in-place upgrade.
      #
      # TODO (fill-in): build the two `Content` instances and run the sniff +
      # `LegacyCleaner`; resolve `[attachment=N]` markup into upload placeholders
      # via the shared attachment seam.
      class Content
        # @param smilies [Hash] smiley code -> replacement, built once in setup.
        # @param attachment_resolver [Object] resolves `[attachment=N]` to uploads.
        def initialize(smilies:, attachment_resolver:)
          @cleaner = LegacyCleaner.new(smilies:, attachment_resolver:)
        end

        # @param post_text [String]
        # @param bbcode_uid [String] the per-post BBCode uid to strip.
        # @param on_embed [#upload, #quote, #mention, nil] the embed sink.
        # @return [String] Discourse Markdown.
        def to_markdown(_post_text, bbcode_uid:, on_embed: nil)
          raise NotImplementedError
        end

        private

        def xml?(text)
          text.start_with?("<r>", "<t>", "<r ", "<t ")
        end
      end
    end
  end
end
