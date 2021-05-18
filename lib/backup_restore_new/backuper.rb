# frozen_string_literal: true

require 'etc'
require 'mini_tarball'

module BackupRestoreNew
  class Backuper
    delegate :log, :log_event, :log_step, :log_warning, :log_error, to: :@logger, private: true
    attr_reader :success

    def initialize(user_id, logger, backup_path_override: nil)
      @user = User.find_by(id: user_id) || Discourse.system_user
      @logger = logger
      @backup_path_override = backup_path_override
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
    rescue => ex
      log_error "Backup failed!", ex
    else
      @success = true
      @backup_path
    ensure
      clean_up
      notify_user
      complete
    end

    private

    def initialize_backup
      log_step("Initializing backup") do
        @success = false
        @warnings = false
        @store = BackupRestore::BackupStore.create

        BackupRestoreNew::Operation.start

        timestamp = Time.now.utc.strftime("%Y-%m-%d-%H%M%S")
        current_db = RailsMultisite::ConnectionManagement.current_db
        archive_directory_override, filename_override = calculate_path_overrides
        archive_directory = archive_directory_override || BackupRestore::LocalBackupStore.base_directory(db: current_db)

        filename = filename_override || begin
          parameterized_title = SiteSetting.title.parameterize.presence || "discourse"
          "#{parameterized_title}-#{timestamp}"
        end

        @backup_filename = "#{filename}.tar"
        @backup_path = File.join(archive_directory, @backup_filename)
        @tmp_directory = File.join(Rails.root, "tmp", "backups", current_db, timestamp)

        FileUtils.mkdir_p(archive_directory)
        FileUtils.mkdir_p(@tmp_directory)
      end
    end

    def create_backup
      MiniTarball::Writer.create(@backup_path) do |writer|
        add_db_dump(writer)
        add_uploads(writer)
        add_optimized_images(writer)
        add_metadata(writer)
      end
    end

    def add_db_dump(tar_writer)
      log_step("Creating database dump") do
        tar_writer.add_file_from_stream(name: BackupRestore::DUMP_FILE, **tar_file_attributes) do |output_stream|
          dumper = Backup::DatabaseDumper.new
          dumper.dump_schema(output_stream)
        end
      end
    end

    def add_uploads(tar_writer)
      if !Backup::UploadBackuper.include_uploads?
        log "Skipping uploads"
        return
      end

      log_step("Adding uploads", with_progress: true) do |progress_logger|
        tar_writer.add_file_from_stream(name: BackupRestore::UPLOADS_FILE, **tar_file_attributes) do |output_stream|
          backuper = Backup::UploadBackuper.new(@tmp_directory, progress_logger)
          @backup_uploads_result = backuper.compress_uploads(output_stream)
        end
      end

      if (error_count = @backup_uploads_result[:failed_ids].size) > 0
        @warnings = true
        log_warning "Failed to add #{error_count} uploads. See logfile for details."
      end
    end

    def add_optimized_images(tar_writer)
      if !Backup::UploadBackuper.include_optimized_images?
        log "Skipping optimized images"
        return
      end

      log_step("Adding optimized images", with_progress: true) do |progress_logger|
        tar_writer.add_file_from_stream(name: BackupRestore::OPTIMIZED_IMAGES_FILE, **tar_file_attributes) do |output_stream|
          backuper = Backup::UploadBackuper.new(@tmp_directory, progress_logger)
          @backup_optimized_images_result = backuper.compress_optimized_images(output_stream)
        end
      end

      if (error_count = @backup_optimized_images_result[:failed_ids].size) > 0
        @warnings = true
        log_warning "Failed to add #{error_count} optimized images. See logfile for details."
      end
    end

    def add_metadata(tar_writer)
      log_step("Adding metadata file") do
        tar_writer.add_file_from_stream(name: BackupRestore::METADATA_FILE, **tar_file_attributes) do |output_stream|
          Backup::MetadataWriter.new(@backup_uploads_result, @backup_optimized_images_result).write(output_stream)
        end
      end
    end

    def upload_backup
      return unless @store.remote?

      file_size = File.size(@backup_path)
      file_size = Object.new.extend(ActionView::Helpers::NumberHelper).number_to_human_size(file_size)

      log_step("Uploading backup (#{file_size})") do
        @store.upload_file(@backup_filename, @backup_path, "application/x-tar")
      end
    end

    def finalize_backup
      log_step("Finalizing backup") do
        DiscourseEvent.trigger(:backup_created)
      end
    end

    def clean_up
      log_step("Cleaning up") do
        @store.delete_old if !Rails.env.development?

        delete_uploaded_archive
        remove_tar_leftovers
        remove_tmp_directory
        @store.reset_cache
      end
    end

    def notify_user
      return if @success && @user.id == Discourse::SYSTEM_USER_ID

      log_step("Notifying user") do
        status = @success ? :backup_succeeded : :backup_failed
        post = SystemMessage.create_from_system_user(
          @user, status, logs: Discourse::Utils.pretty_logs(@logger.logs)
        )

        if @user.id == Discourse::SYSTEM_USER_ID
          post.topic.invite_group(@user, Group[:admins])
        end
      end
    end

    def complete
      begin
        BackupRestoreNew::Operation.finish
      rescue => e
        log_error "Failed to mark operation as finished", e
      end

      if @success
        if @store.remote?
          location = BackupLocationSiteSetting.find_by_value(SiteSetting.backup_location)
          location = I18n.t("admin_js.#{location[:name]}") if location
          log "Backup stored on #{location} as #{@backup_filename}"
        else
          log "Backup stored at: #{@backup_path}"
        end

        if @warnings
          log_warning "Backup completed with warnings!"
        else
          log "Backup completed successfully!"
        end

        log_event "[SUCCESS]"
      else
        log_error "Backup failed!"
        log_event "[FAILED]"
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

    def calculate_path_overrides
      if @backup_path_override.present?
        archive_directory_override = File.dirname(@backup_path_override).sub(/^\.$/, "")

        if archive_directory_override.present? && @store.remote?
          log_warning "Only local backup storage supports overriding backup path."
          archive_directory_override = nil
        end

        filename_override = File.basename(@backup_path_override).sub(/\.(sql\.gz|tar|tar\.gz|tgz)$/i, "")
        [archive_directory_override, filename_override]
      end
    end
  end
end
