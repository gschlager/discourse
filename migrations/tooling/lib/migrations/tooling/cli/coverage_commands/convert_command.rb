# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module CoverageCommands
        # `disco coverage convert [name]`
        #
        # With no argument, asserts that the reference converter covers every
        # IntermediateDB column (see Coverage::ReferenceCheck).
        #
        # With a converter name, scopes analysis to that single converter for
        # inspection and prints its covered columns — it does not run the gate.
        class ConvertCommand < Migrations::CLI::Command
          REFERENCE_CONVERTER = Coverage::ReferenceCheck::REFERENCE_CONVERTER

          self.description = "Check converter coverage of the IntermediateDB schema"

          class Error < StandardError
            include Migrations::CLI::PresentableError
          end

          options { option "-h/--help", "Print out help." }

          # NOTE: avoid `:name` — Samovar reserves it for a command's invocation
          # name, so an absent positional would silently read back as "convert".
          one :converter,
              "Converter to inspect. Without it, every converter is analysed and " \
                "the reference (#{REFERENCE_CONVERTER}) is asserted complete."

          def call
            return print_usage if @options[:help]

            if converter
              inspect_converter(converter.downcase)
            else
              exit 1 unless Coverage::ReferenceCheck.run
            end
          end

          private

          def inspect_converter(converter_name)
            validate_converter!(converter_name)

            result =
              Coverage::ConverterAnalyzer.new(
                Migrations::Converters.path_of(converter_name),
              ).analyze
            written = result.written_columns
            expected = Coverage::SchemaColumns.call

            puts "Columns written by the '#{converter_name}' converter:"
            puts

            if written.empty? && result.unknown_models.empty?
              puts "  (no IntermediateDB.create calls found)"
              return
            end

            written.keys.sort.each do |model_name|
              columns = written[model_name].to_a.sort
              schema_count = expected[model_name]&.columns&.size
              coverage = schema_count ? "#{columns.size}/#{schema_count}" : columns.size.to_s
              puts "  #{model_name} (#{coverage}): #{columns.join(", ")}"

              if (model = expected[model_name]) && (extra = columns - model.columns).any?
                puts "    unknown #{"column".pluralize(extra.size)}: #{extra.join(", ")}".red
              end
            end

            result.unknown_models.keys.sort.each do |model_name|
              locations = result.unknown_models[model_name]
              puts "  #{model_name}: model does not exist (#{locations.join(", ")})".red
            end
          end

          def validate_converter!(converter_name)
            names = Migrations::Converters.names
            return if names.include?(converter_name)

            raise Error, <<~MSG.strip
              Unknown converter name: #{converter_name}
              Valid names are: #{names.join(", ")}
            MSG
          end
        end
      end
    end
  end
end
