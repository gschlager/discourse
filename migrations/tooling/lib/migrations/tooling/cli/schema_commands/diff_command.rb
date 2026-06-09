# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class DiffCommand < BaseCommand
          include DiffOutput

          self.description = "Show differences between configuration and database"

          option "--verbose", :flag, "Show auto-ignored plugin columns."

          def execute
            database = selected_database
            result = schema.diff(database:)
            display_diff(result, database:, verbose: verbose?)
          end
        end
      end
    end
  end
end
