# frozen_string_literal: true

module BackupRestoreNew
  class Factory
    def initialize(logger)
      @logger = logger
    end

    def logger
      @logger
    end

    def create_database_dumper
      Backup::DatabaseDumper.new
    end

    def create_upload_backuper(tmp_directory, progress_logger)
      Backup::UploadBackuper.new(tmp_directory, progress_logger)
    end

    def create_backup_store
      ::BackupRestore::BackupStore.create
    end
  end
end
