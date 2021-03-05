# frozen_string_literal: true

module BackupRestoreNew
  class Backuper
    delegate :log, :log_event, :log_task, :log_warning, :log_error, to: :@logger, private: true
    attr_reader :success

    def initialize(user_id, logger)
      @user = User.find_by(id: user_id) || Discourse.system_user
      @logger = logger
    end

    def run
      log_event "[STARTED]"
      log "User '#{@user.username}' started backup"

      initialize_backup
      add_db_dump
      add_uploads
      upload_backup
      finalize_backup
    rescue SystemExit, SignalException
      log_warning "Backup operation was canceled!"
    rescue StandardError => ex
      log_error "Backup failed!", ex
    else
      @success = true
      @backup_filename
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
        @current_db = RailsMultisite::ConnectionManagement.current_db
        sleep 3
      end
    end

    def add_db_dump
      log_task("Creating database dump") do
        sleep 3
      end
    end

    def add_uploads
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
        sleep 2
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
