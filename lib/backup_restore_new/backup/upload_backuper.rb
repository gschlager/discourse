# frozen_string_literal: true

require 'mini_tarball'

module BackupRestoreNew
  module Backup
    class UploadBackuper
      attr_reader :errors

      def initialize(tmp_directory, progress_logger)
        @tmp_directory = tmp_directory
        @progress_logger = progress_logger
        @errors = []
      end

      def compress_uploads(output_stream)
        @progress_logger.max_progress = Upload.by_users.count

        uploads_gz = Zlib::GzipWriter.new(output_stream, SiteSetting.backup_gzip_compression_level_for_uploads)
        MiniTarball::Writer.use(uploads_gz) do |uploads_tar|
          add_uploaded_files(uploads_tar)
        end
      end

      protected

      def add_uploaded_files(tar_writer)
        Upload.by_users.find_each do |upload|
          paths_of(upload) do |relative_path, absolute_path|
            next if absolute_path.blank?

            if File.exist?(absolute_path)
              tar_writer.add_file(name: relative_path, source_file_path: absolute_path)
            else
              log_error("Failed to locate file with upload ID #{upload.id}")
            end
          end

          @progress_logger.increment
        end
      end

      def paths_of(upload)
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
            log_error("Failed to download file with upload ID #{upload.id} from S3", ex)
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

      def log_error(message, ex = nil)
        @errors << { message: message, ex: ex }
      end
    end
  end
end
