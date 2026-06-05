# frozen_string_literal: true

module Migrations
  module Tooling
    module CLI
      module CheckCommands
        # `disco check coverage` — asserts that the reference converter
        # covers every IntermediateDB column. Runs without Rails.
        class CoverageCommand < Migrations::CLI::Command
          self.description = "Check converter coverage of the IntermediateDB schema"

          options { option "-h/--help", "Print out help." }

          def call
            return print_usage if @options[:help]

            exit 1 unless run
          end

          def run
            Coverage::ReferenceCheck.run
          end
        end
      end
    end
  end
end
