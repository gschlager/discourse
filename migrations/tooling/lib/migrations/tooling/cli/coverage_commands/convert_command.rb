# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module CoverageCommands
        # `disco coverage convert [name]`
        #
        # With no argument, analyses every discovered converter (so an
        # unverifiable call site fails loudly anywhere) and asserts that the
        # reference converter covers every IntermediateDB column.
        #
        # With a converter name, scopes analysis to that single converter for
        # inspection and prints its covered columns — it does not run the gate.
        class ConvertCommand < Migrations::CLI::Command
          # The Discourse converter is the reference implementation: the
          # IntermediateDB schema is modelled on Discourse's own schema, so it is
          # the one converter expected to populate every column. This is
          # structural, not a configurable role, so it is hardcoded.
          REFERENCE_CONVERTER = "discourse"

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
              assert_reference_complete
            end
          end

          private

          def inspect_converter(converter_name)
            validate_converter!(converter_name)

            written = analyze(converter_name)
            expected = Coverage::SchemaColumns.call

            puts "Columns written by the '#{converter_name}' converter:"
            puts

            if written.empty?
              puts "  (no IntermediateDB.create calls found)"
              return
            end

            written.keys.sort.each do |model_name|
              columns = written[model_name].to_a.sort
              schema_count = expected[model_name]&.columns&.size
              coverage = schema_count ? "#{columns.size}/#{schema_count}" : columns.size.to_s
              puts "  #{model_name} (#{coverage}): #{columns.join(", ")}"
            end
          end

          def assert_reference_complete
            converters = Migrations::Converters.names
            ensure_reference_present!(converters)

            # Analyse every converter so an unverifiable call site (a `**` splat or
            # non-literal keyword) fails loudly even in a non-reference converter.
            # Only the reference is asserted against the full schema; every other
            # converter writes a subset of the schema by design.
            written_by_converter = converters.to_h { |name| [name, analyze(name)] }

            expected = Coverage::SchemaColumns.call
            missing = missing_columns(expected, written_by_converter.fetch(REFERENCE_CONVERTER))

            if missing.empty?
              column_count = expected.values.sum { |model| model.columns.size }
              puts "✓ The #{REFERENCE_CONVERTER} converter covers all #{column_count} IntermediateDB columns across #{expected.size} tables.".green
              return
            end

            report_missing(expected, missing)
            exit 1
          end

          # @return [Hash{String => Array<Symbol>}] uncovered columns per model,
          #   only for models that have at least one.
          def missing_columns(expected, written)
            expected.each_with_object({}) do |(model_name, model), missing|
              uncovered = model.columns - written.fetch(model_name, Set.new).to_a
              missing[model_name] = uncovered if uncovered.any?
            end
          end

          def report_missing(expected, missing)
            puts "✗ The #{REFERENCE_CONVERTER} converter does not write every IntermediateDB column.".red
            puts "  Acknowledge each column in the converter (pass it explicitly, `column: nil` if the source has no value):"
            puts

            column_count = 0
            missing
              .keys
              .sort_by { |model_name| expected[model_name].table_name }
              .each do |model_name|
                columns = missing[model_name].sort
                column_count += columns.size
                puts "  #{expected[model_name].table_name}: #{columns.join(", ")}"
              end

            puts
            puts "#{column_count} #{"column".pluralize(column_count)} across #{missing.size} #{"table".pluralize(missing.size)} not covered.".red
          end

          def analyze(converter_name)
            Coverage::ConverterAnalyzer.new(
              Migrations::Converters.path_of(converter_name),
            ).written_columns
          end

          def ensure_reference_present!(converters)
            return if converters.include?(REFERENCE_CONVERTER)

            raise Error, <<~MSG.strip
              Reference converter '#{REFERENCE_CONVERTER}' was not found among the discovered converters: #{converters.join(", ")}.
              The coverage gate cannot run without it.
            MSG
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
