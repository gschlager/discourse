# frozen_string_literal: true

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
        tar_writer.add_file(name: BackupRestore::DUMP_FILE) do |output_stream|
          dumper = DatabaseDumper.new
          dumper.dump_public_schema(output_stream)
        end
      end
    end

    def add_uploads(tar_writer)
      log_task("Adding uploads") do
        sleep 3
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
  end
end
