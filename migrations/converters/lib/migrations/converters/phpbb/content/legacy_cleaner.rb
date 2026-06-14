# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # phpBB-specific pre-clean applied before Markbridge's BBCode parser — and
      # only the subset Markbridge does not already cover. The legacy importer's
      # `text_processor.rb` / `smiley_processor.rb` regexes are the conformance
      # corpus: each is a spec test fed through `Migrations::Converters::Content`,
      # and whatever already round-trips is deleted from here.
      #
      # Candidates to port (verify against Markbridge first):
      #   * uid strip:        /:(?:\w{5,8})\]/
      #   * smilies:          <!-- s:) --><img ...><!-- s:) -->
      #   * magic-url links:  <!-- m -->/<!-- l --> wrappers
      #   * lists:            [list]…[/list:u] / [*]…[/*:m]
      #   * attachments:      [attachment=N]…  (routed to the upload seam)
      #
      # Smilies and attachment filenames are injected as plain lookups (built once
      # in the worker's `setup`), never DB calls, so the processor stays pure.
      class LegacyCleaner
        def initialize(smilies:, attachment_resolver:)
          @smilies = smilies
          @attachment_resolver = attachment_resolver
        end

        # @param text [String]
        # @param bbcode_uid [String]
        # @return [String] cleaned BBCode ready for Markbridge.
        def call(_text, bbcode_uid:)
          raise NotImplementedError
        end
      end
    end
  end
end
