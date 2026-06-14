# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # Private messages -> Discourse PM topics + posts.
      #
      # The legacy converter grouped messages that share a normalized subject +
      # participant set into one PM topic by mutating a `@conversation_map` across
      # items in a serial step. That cross-item state is incompatible with the pure,
      # per-item processor model, so the grouping must move below the contract —
      # into the Source. Two options (see the design doc):
      #   1. Pre-group in SQL: emit one row per conversation (a `MessageTopics` step)
      #      and one per message, each carrying its conversation key. Both stay
      #      parallelizable. (Preferred.)
      #   2. Group in the parent: the Source builds the conversation -> topic-id map
      #      as it streams and stamps each yielded row.
      #
      # TODO (fill-in): pick an approach, then map rows to
      # `IntermediateDB::Topic` (private_message) + `IntermediateDB::Post`.
      class Messages < Conversion::ProgressStep
        source do
          attr_accessor :source_db

          def max_progress
            source_db.count_messages
          end

          def items
            source_db.fetch_messages
          end
        end

        processor do
          attr_accessor :phpbb_config

          def setup
            # @content = Phpbb::Content.new(...)
          end

          def process(item)
            raise NotImplementedError
          end
        end
      end
    end
  end
end
