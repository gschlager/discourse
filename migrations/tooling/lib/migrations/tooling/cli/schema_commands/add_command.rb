# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class AddCommand < BaseCommand
          self.description = "Create a config file for a new table"

          parameter "TABLE_NAME", "The name of the table to add."

          def execute
            database = selected_database
            path = schema.add_table(table_name, database:)
            puts "✓ Created #{path}".green
            puts
            puts "Next steps:"
            puts "  1. Edit the file to configure columns"
            puts "  2. Run '#{Migrations::CLI::BIN} check schema'"
          end
        end
      end
    end
  end
end
