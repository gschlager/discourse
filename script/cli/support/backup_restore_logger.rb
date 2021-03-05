# frozen_string_literal: true

require_relative 'spinner'

module DiscourseCLI
  class BackupRestoreLogger < BackupRestoreNew::Logger::Base
    include HasSpinner

    def log_task(message)
      spin(message, abort_on_error: false) do
        yield
      end
    end

    def log(message, level: BackupRestoreNew::Logger::INFO)
      case level
      when BackupRestoreNew::Logger::INFO
        message = " 💡 #{message}"
      when BackupRestoreNew::Logger::ERROR
        message = message.red
      when BackupRestoreNew::Logger::WARNING
        message = message.yellow
      end

      puts message
    end
  end
end
