# frozen_string_literal: true

require "tmpdir"

module Migrations
  module Tooling
    module Schema
      module DSL
        # Compares the committed generated artifacts (SQL schema, models and
        # enums) with what `disco schema generate` would produce right now.
        # Generation happens in a temporary directory, so the working tree
        # stays untouched.
        class ArtifactsChecker
          Result =
            Data.define(:changed, :missing, :stale) do
              def clean?
                changed.empty? && missing.empty? && stale.empty?
              end
            end

          def initialize(schema_module, database: :intermediate_db)
            @schema = schema_module
            @database = database
            @output_config = schema_module.config.output_config
          end

          def check
            Dir.mktmpdir("disco-schema-check-") do |tmp_root|
              resolved = @schema.generate(database: @database, output_root: tmp_root)
              compare(resolved, tmp_root)
            end
          end

          private

          def compare(resolved, tmp_root)
            changed = []
            missing = []

            expected = expected_files(resolved)
            expected.each do |relative_path|
              committed = File.join(Migrations.root_path, relative_path)
              generated = File.join(tmp_root, relative_path)

              if !File.exist?(committed)
                missing << relative_path
              elsif File.read(committed) != File.read(generated)
                changed << relative_path
              end
            end

            Result.new(changed:, missing:, stale: stale_files(expected))
          end

          # The files generation produces: the SQL schema and one file per
          # model and enum. Manual models are hand-written and skipped by the
          # generator.
          def expected_files(resolved)
            files = [@output_config.schema_file]

            resolved.tables.each do |table|
              next if table.model_mode == :manual
              files << File.join(@output_config.models_directory, ModelWriter.filename_for(table))
            end

            resolved.enums.each do |enum|
              files << File.join(@output_config.enums_directory, EnumWriter.filename_for(enum))
            end

            files
          end

          # Committed generated files that generation no longer produces,
          # e.g. the model of a table that was removed from the config.
          def stale_files(expected)
            expected = expected.to_set
            stale = []

            [@output_config.models_directory, @output_config.enums_directory].uniq.each do |dir|
              Dir[File.join(Migrations.root_path, dir, "*.rb")].each do |path|
                relative_path = Pathname.new(path).relative_path_from(Migrations.root_path).to_s
                next if expected.include?(relative_path)
                next if File.read(path).exclude?(Generator::GENERATED_FILE_MARKER)

                stale << relative_path
              end
            end

            stale.sort
          end
        end
      end
    end
  end
end
