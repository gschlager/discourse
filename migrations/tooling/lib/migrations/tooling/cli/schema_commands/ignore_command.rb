# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class IgnoreCommand < BaseCommand
          self.description = "Add a table to ignored.rb"

          option "--reason", "TEXT", "Optional reason for ignoring the table."

          parameter "TABLE_NAME", "The name of the table to ignore."

          def execute
            database = selected_database
            schema.ignore_table(table_name, reason:, database:)
            puts "✓ Added #{table_name} to ignored.rb".green
          end
        end
      end
    end
  end
end
