# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # Permalink *normalization* rules (regex rewrites that collapse the many
      # phpBB URL shapes onto a canonical form). The per-post `permalinks` rows
      # (url -> post_id) are written by the `Posts` step; this step only seeds the
      # normalization rules, which are a fixed, source-independent list rather than
      # a query.
      #
      # TODO (fill-in): port the `viewtopic.php?t=`, `viewforum.php?f=`,
      # `viewtopic.php?p=` normalizations from the legacy converter and write them
      # via `IntermediateDB::PermalinkNormalization.create(...)`.
      class Permalinks < Conversion::ProgressStep
        source do
          def max_progress
            items.size
          end

          def items
            [] # TODO: the static list of normalization rules.
          end
        end

        processor do
          def process(item)
            raise NotImplementedError
          end
        end
      end
    end
  end
end
