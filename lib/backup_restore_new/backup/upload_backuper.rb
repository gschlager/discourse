# frozen_string_literal: true

require 'mini_tarball'

module BackupRestoreNew
  class UploadBackuper
    def compress_uploads(output_stream)
      uploads_gz = Zlib::GzipWriter.new(output_stream, SiteSetting.backup_gzip_compression_level_for_uploads)
      MiniTarball::Writer.use(uploads_gz) do |uploads_tar|
        add_uploaded_files(uploads_tar)
      end
    end

    protected

    def add_uploaded_files(tar_writer)
      Upload.by_users.find_each do |upload|
        relative_path = Discourse.store.get_path_for_upload(upload)
        absolute_path = File.join(Rails.root, "public", relative_path)
        relative_path.delete_prefix!("/")

        if File.exist?(absolute_path)
          tar_writer.add_file(name: relative_path, source_file_path: absolute_path)
        else
          puts "Missing file: #{absolute_path}"
        end
      end
    end
  end
end
