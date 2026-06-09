# frozen_string_literal: true

require "colored2"

module Migrations
  module Tooling
    module CLI
      module SchemaCommands
        class RefreshPluginsCommand < BaseCommand
          self.description = "Regenerate the plugin manifest"

          option "--force", :flag, "Force regeneration."

          def execute
            database = selected_database
            schema.ensure_ready!(database:, refresh_manifest: false)

            manifest = schema.plugin_manifest

            if force? || !manifest.fresh? || manifest.incomplete?
              puts "Detecting plugin tables and columns..."
              manifest.regenerate!
              if manifest.incomplete?
                failed_plugins = manifest.failed_plugins.join(", ").presence || "(unknown)"
                puts "Plugin manifest updated with warnings (failed plugins: #{failed_plugins})"
              else
                puts "✓ Plugin manifest updated".green
              end
              puts "  Tables: #{manifest.table_count}"
              puts "  Columns: #{manifest.column_count}"
              puts "  Plugins: #{manifest.all_plugin_names.join(", ")}"
            else
              puts "Plugin manifest is up to date"
              puts "  Use --force to regenerate"
            end
          end
        end
      end
    end
  end
end
