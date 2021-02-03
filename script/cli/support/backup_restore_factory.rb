# frozen_string_literal: true

require_relative 'backup_restore_logger'

module DiscourseCLI
  class BackupRestoreFactory < BackupRestore::Factory
    def logger
      @logger ||= BackupRestoreLogger.new
    end
  end
end
