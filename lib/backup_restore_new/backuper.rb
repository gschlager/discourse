# frozen_string_literal: true

require 'etc'
require 'mini_tarball'
require_relative 'backup/database_dumper'

module BackupRestoreNew
  class Backuper
    delegate :log, :log_event, :log_task, :log_warning, :log_error, to: :@logger, private: true
    attr_reader :success

    def initialize(user_id, logger, filename: nil)
      @user = User.find_by(id: user_id) || Discourse.system_user
      @logger = logger
      @filename_override = filename
    end

    def run
      log_event "[STARTED]"
      log "User '#{@user.username}' started backup"

      initialize_backup
      create_backup
      upload_backup
      finalize_backup
    rescue SystemExit, SignalException
      log_warning "Backup operation was canceled!"
    rescue StandardError => ex
      log_error "Backup failed!", ex
    else
      @success = true
      @backup_path
    ensure
      clean_up
      notify_user

      log "Finished successfully!" if @success
      log_event @success ? "[SUCCESS]" : "[FAILED]"
    end

    protected

    def initialize_backup
      log_task("Initializing backup") do
        @success = false
        @backup_path = calculate_backup_path
      end
    end

    def calculate_backup_path
      filename = @filename_override || begin
        parameterized_title = SiteSetting.title.parameterize.presence || "discourse"
        timestamp = Time.now.utc.strftime("%Y-%m-%d-%H%M%S")
        "#{parameterized_title}-#{timestamp}"
      end

      current_db = RailsMultisite::ConnectionManagement.current_db
      archive_directory = BackupRestore::LocalBackupStore.base_directory(db: current_db)
      File.join(archive_directory, "#{filename}.tar")
    end

    def create_backup
      MiniTarball::Writer.create(@backup_path) do |writer|
        add_db_dump(writer)
        add_uploads(writer)
      end
    end

    def add_db_dump(tar_writer)
      log_task("Creating database dump") do
        tar_writer.add_file(name: BackupRestore::DUMP_FILE, **tar_file_attributes) do |output_stream|
          dumper = DatabaseDumper.new
          dumper.dump_public_schema(output_stream)
        end
      end
    end

    def add_uploads(tar_writer)
      log_task("Adding uploads") do
        tar_writer.add_file(name: "uploads.tar.gz", **tar_file_attributes) do |output_stream|
          uploads_gz = Zlib::GzipWriter.new(output_stream, SiteSetting.backup_gzip_compression_level_for_uploads)
          MiniTarball::Writer.use(uploads_gz) do |uploads_tar|
            add_uploaded_files(uploads_tar)
          end
        end
      end
    end

    def add_uploaded_files(tar_writer)
      Upload.by_users.find_each do |upload|
        relative_path = Discourse.store.get_path_for_upload(upload)
        absolute_path = File.join(Rails.root, "public", relative_path)
        relative_path.delete_prefix!("/")

        if File.exist?(absolute_path)
          tar_writer.add_existing_file(name: relative_path, source_file_path: absolute_path)
        else
          puts "Missing file: #{absolute_path}"
        end
      end
    end

    def upload_backup
      log_task("Uploading backup") do
        sleep 3
      end
    end

    def finalize_backup
      log_task("Finalizing backup") do
        sleep(3)
      end
    end

    def clean_up
      log_task("Cleaning up") do
        sleep 2
      end
    end

    def notify_user
      log_task("Notifying user") do
        sleep 1
      end
    end

    def tar_file_attributes
      {
        uid: Process.uid,
        gid: Process.gid,
        uname: Etc.getpwuid(Process.uid).name,
        gname: Etc.getgrgid(Process.gid).name,
      }
    end
  end
end
