# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      # `disco check` — the single entrypoint for all source-tree checks.
      # Without a subcommand it runs every check in dependency order and
      # stops at the first failing link, since everything downstream of a
      # stale link would report against stale inputs.
      class CheckCommand < Migrations::CLI::Command
        self.description = "Run all schema and converter checks"

        subcommand "schema", CheckCommands::SchemaCommand.description, CheckCommands::SchemaCommand
        subcommand "coverage",
                   CheckCommands::CoverageCommand.description,
                   CheckCommands::CoverageCommand

        # `disco check` with no subcommand runs every check. Clamp would otherwise
        # show help here, so intercept the no-argument case; everything else
        # (a subcommand, `--help`) goes through the normal Clamp dispatch.
        def run(arguments)
          return super unless arguments.empty?

          # The schema checks need Rails. This command itself doesn't declare
          # `requires_rails!` so that `check coverage` and `--help` stay
          # Rails-free; the all-checks mode boots it here instead.
          Migrations.load_rails_environment(quiet: true)
          run_all
        end

        private

        def run_all
          puts "Checking schema config and generated files...".bold
          unless build_check(CheckCommands::SchemaCommand).perform
            puts
            puts "Skipping the remaining checks, they would run against stale inputs.".red
            exit 1
          end

          puts
          puts "Checking converter coverage...".bold
          exit 1 unless build_check(CheckCommands::CoverageCommand).perform
        end

        # Instantiate a check sub-command with its option defaults applied, so it
        # can be run directly (via `#perform`) instead of through argv dispatch.
        def build_check(command_class)
          command_class.new(invocation_path, context).tap { |command| command.parse([]) }
        end
      end
    end
  end
end
