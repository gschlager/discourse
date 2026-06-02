# frozen_string_literal: true

module Migrations
  module Tooling
    module Coverage
      # Computes, for a single converter, the union of IntermediateDB columns it
      # writes via `.create` across all of its step and helper sources. Unioning
      # per model across every call site means a column written in only one branch
      # of a conditional still counts as covered.
      class ConverterAnalyzer
        # @param converter_path [String] the converter's root source directory
        def initialize(converter_path)
          @converter_path = converter_path
        end

        # @return [Hash{String => Set<Symbol>}] written columns per model name
        def written_columns
          source_files.each_with_object({}) do |file, written|
            CreateCallScanner
              .scan(File.read(file), path: file)
              .each { |model_name, columns| (written[model_name] ||= Set.new).merge(columns) }
          end
        end

        private

        def source_files
          Dir[File.join(@converter_path, "**", "*.rb")].sort
        end
      end
    end
  end
end
