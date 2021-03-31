# frozen_string_literal: true

require 'json'

module BackupRestoreNew
  module Backup
    class MetadataWriter
      def initialize(uploads_result, optimized_images_result)
        @upload_stats = result_to_stats(uploads_result)
        @optimized_image_stats = result_to_stats(optimized_images_result)
      end

      def write(output_stream)
        data = {
          version: BackupRestore.current_version,
          git_version: Discourse.git_version,
          git_branch: Discourse.git_branch,
          plugins: plugin_list,
          base_url: Discourse.base_url,
          cdn_url: Discourse.asset_host,
          s3_base_url: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_base_url : nil,
          s3_cdn_url: SiteSetting.Upload.enable_s3_uploads ? SiteSetting.Upload.s3_cdn_url : nil,
          db_name: RailsMultisite::ConnectionManagement.current_db,
          multisite: Rails.configuration.multisite,
          uploads: @upload_stats,
          optimized_images: @optimized_image_stats
        }

        output_stream.write(JSON.pretty_generate(data))
      end

      private

      def result_to_stats(result)
        {
          total_count: result&.dig(:total_count) || 0,
          included_count: result&.dig(:included_count) || 0,
          missing_count: result&.dig(:failed_ids)&.size || 0,
        }
      end

      def plugin_list
        Discourse.visible_plugins.map do |plugin|
          {
            name: plugin.name,
            enabled: plugin.enabled?
          }
        end
      end
    end
  end
end
