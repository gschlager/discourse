# frozen_string_literal: true

module Migrations
  module Importer
    module CLI
      class ImportCommand < Migrations::CLI::Command
        requires_rails!

        self.description = "Import the IntermediateDB into a Discourse database"

        option "--reset", :flag, "Reset MappingsDB before importing data."
        option "--only",
               "STEPS",
               "Run only the specified steps (comma-separated).",
               default: [] do |value|
          STEP_LIST.call(value)
        end
        option "--skip",
               "STEPS",
               "Skip the specified steps (comma-separated).",
               default: [] do |value|
          STEP_LIST.call(value)
        end

        def execute
          Importer.execute(reset: reset?, only:, skip:)
        end
      end
    end
  end
end
