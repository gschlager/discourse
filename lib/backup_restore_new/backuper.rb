# frozen_string_literal: true

require 'etc'
require 'mini_mime'
require 'mini_tarball'
require_relative 'backup/database_dumper'
require_relative 'backup/upload_backuper'

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
        @store = BackupRestore::BackupStore.create

        timestamp = Time.now.utc.strftime("%Y-%m-%d-%H%M%S")
        current_db = RailsMultisite::ConnectionManagement.current_db
        archive_directory = BackupRestore::LocalBackupStore.base_directory(db: current_db)

        filename = @filename_override || begin
          parameterized_title = SiteSetting.title.parameterize.presence || "discourse"
          "#{parameterized_title}-#{timestamp}"
        end

        @backup_path = File.join(archive_directory, "#{filename}.tar")
        @tmp_directory = File.join(Rails.root, "tmp", "backups", current_db, timestamp)

        FileUtils.mkdir_p(archive_directory)
        FileUtils.mkdir_p(@tmp_directory)
      end
    end

    def create_backup
      MiniTarball::Writer.create(@backup_path) do |writer|
        add_db_dump(writer)
        add_uploads(writer)
      end
    end

    def add_db_dump(tar_writer)
      log_task("Creating database dump") do
        tar_writer.add_file_from_stream(name: BackupRestore::DUMP_FILE, **tar_file_attributes) do |output_stream|
          dumper = DatabaseDumper.new
          dumper.dump_public_schema(output_stream)
        end
      end
    end

    def add_uploads(tar_writer)
      log_task("Adding uploads", with_progress: true) do |progress_logger|
        tar_writer.add_file_from_stream(name: BackupRestore::UPLOADS_FILE, **tar_file_attributes) do |output_stream|
          backuper = UploadBackuper.new(@tmp_directory, progress_logger)
          backuper.compress_uploads(output_stream)
        end
      end
    end

    def upload_backup
      return unless @store.remote?

      file_size = File.size(@backup_path)
      file_size = Object.new.extend(ActionView::Helpers::NumberHelper).number_to_human_size(file_size)

      log_task("Uploading backup (#{file_size})") do
        filename = File.basename(@backup_path)
        content_type = MiniMime.lookup_by_filename(filename).content_type
        @store.upload_file(@backup_filename, filename, content_type)
      end
    end

    def finalize_backup
      log_task("Finalizing backup") do
        DiscourseEvent.trigger(:backup_created)
      end
    end

    def clean_up
      log_task("Cleaning up") do

      end
    end

    def notify_user
      return if @success && @user.id == Discourse::SYSTEM_USER_ID

      log_task("Notifying user") do
        status = @success ? :backup_succeeded : :backup_failed
        post = SystemMessage.create_from_system_user(
          @user, status, logs: Discourse::Utils.pretty_logs(@logger.logs)
        )

        if @user.id == Discourse::SYSTEM_USER_ID
          post.topic.invite_group(@user, Group[:admins])
        end
      end
    end

    def tar_file_attributes
      @tar_file_attributes ||= {
        uid: Process.uid,
        gid: Process.gid,
        uname: Etc.getpwuid(Process.uid).name,
        gname: Etc.getgrgid(Process.gid).name,
      }
    end
  end
end
