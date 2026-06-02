# frozen_string_literal: true

require "prism"

module Migrations
  module Tooling
    module Coverage
      # Walks a Ruby source string with Prism and collects, per IntermediateDB
      # model, the keyword names passed to every `IntermediateDB::<Model>.create`
      # call site.
      #
      # Converter call sites use the bare `IntermediateDB::<Model>` receiver
      # (resolved lexically through `Conversion::Step`), but the same receiver may
      # also be written with leading qualification (e.g.
      # `Database::IntermediateDB::Upload`). We therefore match on the trailing
      # `IntermediateDB::<Const>` segment regardless of qualification, then resolve
      # `<Const>` against `Migrations::Database::IntermediateDB` and confirm it
      # responds to `:create` before trusting the match.
      #
      # A column passed via `**splat` or a non-literal keyword can't be verified
      # statically, so the scanner raises an {AnalysisError} rather than silently
      # under-reporting.
      class CreateCallScanner < Prism::Visitor
        INTERMEDIATE_DB = :IntermediateDB
        private_constant :INTERMEDIATE_DB

        # @param source [String] Ruby source to analyse
        # @param path [String] source location, used only in error messages
        # @return [Hash{String => Set<Symbol>}] written columns per model name
        def self.scan(source, path:)
          result = Prism.parse(source)

          unless result.success?
            details = result.errors.map { |e| "#{e.message} (line #{e.location.start_line})" }
            raise AnalysisError, "Failed to parse #{path}: #{details.join(", ")}"
          end

          scanner = new(path)
          result.value.accept(scanner)
          scanner.columns
        end

        attr_reader :columns

        def initialize(path)
          super()
          @path = path
          @columns = Hash.new { |hash, key| hash[key] = Set.new }
        end

        def visit_call_node(node)
          record_create_call(node)
          super
        end

        private

        def record_create_call(node)
          return unless node.name == :create

          model_name = intermediate_db_model(node.receiver)
          return unless model_name

          collect_keywords(node, model_name)
        end

        # Returns the model's constant name (String) when `receiver` is a
        # `…::IntermediateDB::<Const>` path that resolves to a model responding to
        # `:create`, otherwise nil.
        def intermediate_db_model(receiver)
          return unless receiver.is_a?(Prism::ConstantPathNode)
          return unless const_name(receiver.parent) == INTERMEDIATE_DB

          const = receiver.name
          model =
            begin
              Migrations::Database::IntermediateDB.const_get(const, false)
            rescue NameError
              return
            end
          return unless model.respond_to?(:create)

          const.to_s
        end

        def const_name(node)
          case node
          when Prism::ConstantReadNode, Prism::ConstantPathNode
            node.name
          end
        end

        def collect_keywords(node, model_name)
          arguments = node.arguments
          return unless arguments

          arguments.arguments.each do |argument|
            next unless argument.is_a?(Prism::KeywordHashNode)

            argument.elements.each { |element| record_keyword(element, model_name, node) }
          end
        end

        def record_keyword(element, model_name, node)
          if element.is_a?(Prism::AssocSplatNode)
            raise AnalysisError, unverifiable_message("a `**` splat", model_name, node)
          end

          key = element.key if element.is_a?(Prism::AssocNode)
          unless key.is_a?(Prism::SymbolNode)
            raise AnalysisError, unverifiable_message("a non-literal keyword", model_name, node)
          end

          @columns[model_name] << key.unescaped.to_sym
        end

        def unverifiable_message(what, model_name, node)
          "Cannot statically analyse `IntermediateDB::#{model_name}.create` at " \
            "#{@path}:#{node.location.start_line}: it passes #{what}. " \
            "Pass each column as an explicit keyword so coverage can be verified."
        end
      end
    end
  end
end
