# frozen_string_literal: true

require 'mini_tarball'

module BackupRestoreNew
  module Backup
    class UploadBackuper
      def self.include_original_files?
        Upload.exists?(Upload.by_users.local) ||
          (SiteSetting.include_s3_uploads_in_backups && Upload.exists?(Upload.by_users.remote))
      end

      def self.include_optimized_files?
        # never include optimized images stored on S3
        SiteSetting.include_thumbnails_in_backups && OptimizedImage.exists?(OptimizedImage.by_users.local)
      end

      def initialize(tmp_directory, progress_logger)
        @tmp_directory = tmp_directory
        @progress_logger = progress_logger
      end

      def compress_original_files(output_stream)
        @failed_ids = []
        @progress_logger.start(Upload.by_users.count)

        with_gzip(output_stream) do |tar_writer|
          add_original_files(tar_writer)
        end

        @failed_ids
      end

      def compress_optimized_files(output_stream)
        @failed_ids = []
        @progress_logger.start(OptimizedImage.by_users.count)

        with_gzip(output_stream) do |tar_writer|
          add_optimized_files(tar_writer)
        end

        @failed_ids
      end

      protected

      def with_gzip(output_stream)
        uploads_gz = Zlib::GzipWriter.new(output_stream, SiteSetting.backup_gzip_compression_level_for_uploads)
        MiniTarball::Writer.use(uploads_gz) do |uploads_tar|
          yield(uploads_tar)
        end
      end

      def add_original_files(tar_writer)
        Upload.by_users.find_each do |upload|
          paths_of_upload(upload) do |relative_path, absolute_path|
            if absolute_path.present?
              if File.exist?(absolute_path)
                tar_writer.add_file(name: relative_path, source_file_path: absolute_path)
              else
                @failed_ids << upload.id
                @progress_logger.log("Failed to locate file for upload with ID #{upload.id}")
              end
            end
          end

          @progress_logger.increment
        end
      end

      def add_optimized_files(tar_writer)
        OptimizedImage.by_users.local.find_each do |optimized_image|
          relative_path = base_store.get_path_for_optimized_image(optimized_image)
          absolute_path = File.join(upload_path_prefix, relative_path)

          if File.exist?(absolute_path)
            tar_writer.add_file(name: relative_path, source_file_path: absolute_path)
          else
            @failed_ids << optimized_image.id
            @progress_logger.log("Failed to locate file for optimized image with ID #{optimized_image.id}")
          end

          @progress_logger.increment
        end
      end

      def paths_of_upload(upload)
        is_local_upload = upload.local?
        relative_path = base_store.get_path_for_upload(upload)

        if is_local_upload
          absolute_path = File.join(upload_path_prefix, relative_path)
        else
          absolute_path = File.join(@tmp_directory, upload.sha1)

          begin
            s3_store.download_file(upload, absolute_path)
          rescue => ex
            absolute_path = nil
            @failed_ids << upload.id
            @progress_logger.log("Failed to download file from S3 for upload with ID #{upload.id}", ex)
          end
        end

        yield(relative_path, absolute_path)

        FileUtils.rm_f(absolute_path) if !is_local_upload && absolute_path
      end

      def base_store
        @base_store ||= FileStore::BaseStore.new
      end

      def s3_store
        @s3_store ||= FileStore::S3Store.new
      end

      def upload_path_prefix
        @upload_path_prefix ||= File.join(Rails.root, "public", base_store.upload_path)
      end
    end
  end
end
