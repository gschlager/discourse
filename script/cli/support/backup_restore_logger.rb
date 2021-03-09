# frozen_string_literal: true

require 'ruby-progressbar'
require_relative 'spinner'

module DiscourseCLI
  class BackupRestoreLogger < BackupRestoreNew::Logger::Base
    include HasSpinner

    def log_task(message, with_progress: false)
      spin(message, abort_on_error: false) do |spinner|
        if with_progress
          yield(BackupRestoreProgressLogger.new(message, spinner))
        else
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
    def initialize(message, spinner)
      @message = message
      @spinner = spinner
      @max_progress = 0
      @current_progress = 0
      @last_update = Time.now
    end

    def max_progress=(value)
      @spinner.update(max: value)
    end

    def increment
      @current_progress += 1

      if (Time.now - @last_update) > 0.5
        @spinner.update(current: @current_progress)
        @last_update = Time.now
      end
    end
  end
end
