# frozen_string_literal: true

require 'thor'

module DiscourseCLI
  class BackupCommand < Thor

    desc "create", "Creates a backup"
    def create
      DiscourseCLI.load_rails
      require_relative '../support/backup_restore_logger'

      backuper = BackupRestoreNew::Backuper.new(
        Discourse::SYSTEM_USER_ID,
        BackupRestoreLogger.new("backup-create")
      )
      backuper.run

      exit(1) unless backuper.success
    end

    desc "restore FILENAME", "Restores a backup"
    def restore(filename)

    end

    desc "list", "Lists existing backups"
    def list

    end

    desc "delete", "Deletes a backup"
    def delete

    end

    desc "download", "Downloads a backup"
    def download

    end
  end
end
