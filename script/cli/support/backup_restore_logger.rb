# frozen_string_literal: true

require 'ruby-progressbar'
require_relative 'spinner'

module DiscourseCLI
  class BackupRestoreLogger < BackupRestoreNew::Logger::Base
    include HasSpinner

    def log_task(message, with_progress: false)
      if with_progress
        yield(BackupRestoreProgressLogger.new(message))
      else
        spin(message, abort_on_error: false) do
          yield
        end
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

    def log_progress(current_progress)
      @progressbar
    end
  end

  class BackupRestoreProgressLogger < BackupRestoreNew::Logger::BaseProgressLogger
    def initialize(message)
      @progressbar = ProgressBar.create(title: message)
    end

    def max_progress=(value)
      @progressbar.total = value
    end

    def increment
      @progressbar.increment
    end
  end
end
