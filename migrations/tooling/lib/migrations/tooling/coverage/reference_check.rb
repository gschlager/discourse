# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module Coverage
      # Asserts that the reference converter writes every IntermediateDB
      # column, and that no converter writes columns or models that don't
      # exist in the schema — those call sites would raise at runtime, and
      # typically are leftovers of a schema change. Analysing every discovered
      # converter also means an unverifiable call site (a `**` splat or
      # non-literal keyword) fails loudly even in a non-reference converter.
      # Prints its findings and returns whether the check passed.
      class ReferenceCheck
        # The Discourse converter is the reference implementation: the
        # IntermediateDB schema is modelled on Discourse's own schema, so it
        # is the one converter expected to populate every column. This is
        # structural, not a configurable role, so it is hardcoded.
        REFERENCE_CONVERTER = "discourse"

        # The IntermediateDB linkage models that `PostEmbedWriter` writes. A
        # converter that drains its embeds through that helper (rather than with
        # literal `.create` call sites) covers every column of these tables; the
        # scanner flags the delegation, and `covered_columns` credits them here.
        # See `CreateCallScanner::POST_EMBED_WRITER`.
        EMBED_LINKAGE_MODELS = %w[
          PostUpload
          PostQuote
          PostMention
          PostLink
          PostPoll
          PostEvent
        ].freeze

        class Error < StandardError
          include Migrations::CLI::PresentableError
        end

        def self.run
          new.run
        end

        def run
          converters = Migrations::Converters.names
          ensure_reference_present!(converters)

          results = converters.to_h { |name| [name, analyze(name)] }
          expected = SchemaColumns.call

          passed = true

          # Unknown columns and models are errors for every converter, not
          # just the reference: there is no legitimate reason to write
          # something the schema doesn't know.
          converters.each do |name|
            unknown_columns = unknown_columns(expected, covered_columns(results.fetch(name), expected))
            unknown_models = results.fetch(name).unknown_models

            if unknown_columns.any? || unknown_models.any?
              report_unknown(name, expected, unknown_columns, unknown_models)
              passed = false
            end
          end

          # Only the reference is asserted against the full schema; every
          # other converter writes a subset of the schema by design.
          missing =
            missing_columns(expected, covered_columns(results.fetch(REFERENCE_CONVERTER), expected))
          if missing.any?
            report_missing(expected, missing)
            passed = false
          end

          if passed
            column_count = expected.values.sum { |model| model.columns.size }
            puts "✓ The #{REFERENCE_CONVERTER} converter covers all #{column_count} IntermediateDB columns across #{expected.size} tables.".green
          end

          passed
        end

        private

        # The columns a converter covers: those written at literal `.create` call
        # sites, plus — when it drains its embeds through `PostEmbedWriter` — every
        # column of the linkage tables that helper writes.
        #
        # @return [Hash{String => Set<Symbol>}]
        def covered_columns(result, expected)
          written = result.written_columns
          return written unless result.delegates_post_embeds

          written = written.dup
          EMBED_LINKAGE_MODELS.each do |model_name|
            next unless (model = expected[model_name])
            written[model_name] = (written[model_name] || Set.new) | model.columns
          end
          written
        end

        # @return [Hash{String => Array<Symbol>}] uncovered columns per model,
        #   only for models that have at least one.
        def missing_columns(expected, written)
          expected.each_with_object({}) do |(model_name, model), missing|
            uncovered = model.columns - written.fetch(model_name, Set.new).to_a
            missing[model_name] = uncovered if uncovered.any?
          end
        end

        # @return [Hash{String => Array<Symbol>}] written columns the model's
        #   `create` doesn't accept, per model. Models outside the generated
        #   contract (manual models like Upload) have a bespoke API and are
        #   skipped.
        def unknown_columns(expected, written)
          written.each_with_object({}) do |(model_name, columns), unknown|
            model = expected[model_name]
            next unless model

            extra = columns.to_a - model.columns
            unknown[model_name] = extra.sort if extra.any?
          end
        end

        def report_unknown(converter_name, expected, unknown_columns, unknown_models)
          if unknown_columns.any?
            puts "✗ The #{converter_name} converter writes columns that don't exist in the IntermediateDB schema".red
            puts "  (stale call sites after a schema change?):"
            puts

            unknown_columns
              .keys
              .sort_by { |model_name| expected[model_name].table_name }
              .each do |model_name|
                puts "  #{expected[model_name].table_name}: #{unknown_columns[model_name].join(", ")}"
              end

            puts
          end

          if unknown_models.any?
            puts "✗ The #{converter_name} converter writes to IntermediateDB models that don't exist:".red
            puts

            unknown_models.keys.sort.each do |model_name|
              puts "  #{model_name} (#{unknown_models[model_name].join(", ")})"
            end

            puts
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
          ConverterAnalyzer.new(Migrations::Converters.path_of(converter_name)).analyze
        end

        def ensure_reference_present!(converters)
          return if converters.include?(REFERENCE_CONVERTER)

          raise Error, <<~MSG.strip
            Reference converter '#{REFERENCE_CONVERTER}' was not found among the discovered converters: #{converters.join(", ")}.
            The coverage check cannot run without it.
          MSG
        end
      end
    end
  end
end
