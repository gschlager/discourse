# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        # Shared behaviour for `disco schema <sub>` commands: the `--db` option,
        # database validation, and access to the schema DSL module. Subclasses
        # inherit the `--db` option automatically.
        class BaseCommand < Migrations::CLI::Command
          requires_rails!

          option "--db", "NAME", "Database configuration to use.", default: "intermediate_db"

          def schema
            Schema
          end

          def selected_database
            database = db.to_s
            validate_database_option!(database)
            database
          end

          def validate_database_option!(database)
            unless File.directory?(schema.schema_root_path)
              raise schema::ConfigError,
                    "Schema configuration directory not found: #{schema.schema_root_path}"
            end

            available = schema.available_databases
            return if available.include?(database)

            raise schema::ConfigError,
                  "Unknown database '#{database}'. Available: #{available.join(", ")}"
          end
        end
      end
    end
  end
end
