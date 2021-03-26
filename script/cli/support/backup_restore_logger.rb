# frozen_string_literal: true

require 'ruby-progressbar'
require_relative 'spinner'

module DiscourseCLI
  class BackupRestoreLogger < BackupRestoreNew::Logger::Base
    include HasSpinner

    def log_task(message, with_progress: false)
      if with_progress
        logger = BackupRestoreProgressLogger.new(message)
        begin
          yield(logger)
          logger.success
        rescue StandardError
          logger.error
        end
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
  end

  class BackupRestoreProgressLogger < BackupRestoreNew::Logger::BaseProgressLogger
    def initialize(message)
      @message = message
    end

    def start(max_value)
      @progressbar = ProgressBar.create(
        format: '%t | %c / %C | %E',
        title: " ⠒  #{message}",
        total: max_value,
        autofinish: false
      )
    end

    def increment
      @progressbar.increment
    end

    def log(message, ex = nil)
      # write to log file
    end

    def success
      @progressbar.title = " ✓  ".bold.green + @message
      @progressbar.finish
    end

    def error
      @progressbar.title = " ✘  ".bold.red + @message
      @progressbar.finish
    end
  end
end
