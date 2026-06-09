# frozen_string_literal: true

module Migrations
  module Tooling
    module CLI
      class SchemaCommand < Migrations::CLI::Command
        self.description = "Manage database schemas"

        subcommand "generate",
                   SchemaCommands::GenerateCommand.description,
                   SchemaCommands::GenerateCommand
        subcommand "list", SchemaCommands::ListCommand.description, SchemaCommands::ListCommand
        subcommand "diff", SchemaCommands::DiffCommand.description, SchemaCommands::DiffCommand
        subcommand "add", SchemaCommands::AddCommand.description, SchemaCommands::AddCommand
        subcommand "ignore",
                   SchemaCommands::IgnoreCommand.description,
                   SchemaCommands::IgnoreCommand
        subcommand "unignore",
                   SchemaCommands::UnignoreCommand.description,
                   SchemaCommands::UnignoreCommand
        subcommand "refresh-plugins",
                   SchemaCommands::RefreshPluginsCommand.description,
                   SchemaCommands::RefreshPluginsCommand
      end
    end
  end
end
