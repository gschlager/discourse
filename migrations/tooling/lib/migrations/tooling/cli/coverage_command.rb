# frozen_string_literal: true

module Migrations
  module Tooling
    module CLI
      class CoverageCommand < Migrations::CLI::Command
        self.description = "Analyse converter coverage of the IntermediateDB schema"

        nested :command, { "convert" => CoverageCommands::ConvertCommand }

        def call
          if @command
            @command.call
          else
            print_usage
          end
        end
      end
    end
  end
end
