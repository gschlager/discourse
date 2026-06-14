# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # TODO: Port from the legacy phpBB converter and the design doc. Map each
      # source row to `IntermediateDB::<Model>.create(...)`, acknowledging every
      # IntermediateDB column (pass `column: nil` where phpBB has no value).
      class Topics < Conversion::ProgressStep
        source do
          attr_accessor :source_db

          def max_progress
            source_db.count_topics
          end

          def items
            source_db.fetch_topics
          end
        end

        processor do
          attr_accessor :phpbb_config

          def process(item)
            raise NotImplementedError
          end
        end
      end
    end
  end
end
