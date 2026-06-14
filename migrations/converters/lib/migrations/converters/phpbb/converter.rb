# frozen_string_literal: true

module Migrations
  module Converters
    module Phpbb
      # Entry point for the phpBB converter. Opens the source database once in the
      # main process and threads it — plus the static phpBB config — to every
      # step's source/processor roles via `step_args`.
      #
      # Steps are discovered automatically from the constants in this module (every
      # class that is a `Conversion::ProgressStep`); see `Conversion::Base#steps`.
      #
      # This is a skeleton: `Phpbb::Source` and each step's `process` still raise
      # `NotImplementedError`. See `migrations/docs/converter-architecture.md` and
      # the legacy `script/import_scripts/phpbb3` importer for the mapping to port.
      class Converter < Conversion::Base
        def setup
          @source_db = Source.create(settings[:source_db])
          @phpbb_config = @source_db.config
        end

        def step_args(_step_class)
          { source_db: @source_db, phpbb_config: @phpbb_config }
        end
      end
    end
  end
end
