# frozen_string_literal: true

require 'thor'

module DiscourseCLI
  class BackupCommand < Thor

    desc "create", "Creates a backup"
    def create

    end

    desc "restore FILENAME", "Restores a backup"
    method_option :uploads, type: :boolean, default: true
    method_option :remap, type: :boolean, default: true
    method_option :rebake, type: :boolean, default: true
    method_option :interactive, type: :boolean, default: true
    method_option :path, type: :string, desc: "Overrides the backup location and looks for the backup file in this directory."
    def restore(filename)
      DiscourseCLI.load_rails
      require_relative '../support/backup_restore_factory'

      begin
        restorer = BackupRestore::Restorer.new(
          user_id: Discourse.system_user.id,
          filename: filename,
          disable_emails: options[:disable_emails],
          factory: BackupRestoreFactory.new(user_id: Discourse.system_user.id)
        )
        restorer.run
      rescue BackupRestore::FilenameMissingError
        puts '', 'The filename argument was missing.', ''
        usage
      rescue BackupRestore::RestoreDisabledError
        puts '', 'Restores are not allowed.', 'An admin needs to set allow_restore to true in the site settings before restores can be run.'
        puts "Enable now with", '', "discourse enable_restore", ''
        puts 'Restore cancelled.', ''
      end

      exit(1) unless restorer.try(:success)
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
