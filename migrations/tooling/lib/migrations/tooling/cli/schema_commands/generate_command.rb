# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class GenerateCommand < BaseCommand
          self.description = "Generate SQL schema, Ruby models, and enum files"

          def execute
            database = selected_database
            result = schema.generate(database:)
            resolved = result.resolved

            puts
            table_count = resolved.tables.size
            enum_count = resolved.enums.size
            tables_str = "#{table_count} #{"table".pluralize(table_count)}"
            enums_str = "#{enum_count} #{"enum".pluralize(enum_count)}"
            puts "✓ Generated #{tables_str}, #{enums_str}".green

            result.deleted_files.each do |path|
              puts "✓ Deleted #{path} (no longer generated)".yellow
            end
          end
        end
      end
    end
  end
end
