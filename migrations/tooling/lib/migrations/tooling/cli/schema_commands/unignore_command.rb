# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class UnignoreCommand < BaseCommand
          self.description = "Remove a table from ignored.rb"

          parameter "TABLE_NAME", "The name of the table to remove from ignored.rb."

          def execute
            database = selected_database
            schema.unignore_table(table_name, database:)
            puts "✓ Removed #{table_name} from ignored.rb".green
          end
        end
      end
    end
  end
end
