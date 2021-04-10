# frozen_string_literal: true

require 'colored2'
require 'ruby-progressbar'
require_relative 'spinner'

module DiscourseCLI
  class BackupRestoreLogger < BackupRestoreNew::Logger::Base
    include HasSpinner

    def initialize(name)
      super()

      timestamp = Time.now.utc.strftime("%Y-%m-%dT%H%M%SZ")
      path = File.join(Rails.root, "tmp", "cli")
      FileUtils.mkdir_p(path)
      path = File.join(path, "#{name}-#{timestamp}.log")

      @logfile = File.new(path, "w")
      log_to_stdout("Logging to #{path}")
    end

    def close
      @logfile.close
    end

    def log_step(message, with_progress: false)
      if with_progress
        logger = BackupRestoreProgressLogger.new(message, self)
        begin
          yield(logger)
          logger.success
        rescue Exception
          logger.error
          raise
        end
      else
        spin(message, abort_on_error: false) do
          yield
        end
      end
      nil
    end

    def log(message, level: BackupRestoreNew::Logger::INFO)
      log_to_stdout(message, level)
      log_to_logfile(message, level)
    end

    def log_to_stdout(message, level = BackupRestoreNew::Logger::INFO)
      case level
      when BackupRestoreNew::Logger::INFO
        puts " INFO ".blue + " #{message}"
      when BackupRestoreNew::Logger::ERROR
        puts " FAIL ".red + " #{message}"
      when BackupRestoreNew::Logger::WARNING
        puts " WARN ".yellow + " #{message}"
      else
        puts message
      end
    end

    def log_to_logfile(message, level = BackupRestoreNew::Logger::INFO)
      case level
      when BackupRestoreNew::Logger::INFO
        @logfile.puts("INFO: #{message}")
      when BackupRestoreNew::Logger::ERROR
        @logfile.puts("ERROR: #{message}")
      when BackupRestoreNew::Logger::WARNING
        @logfile.puts("WARN: #{message}")
      else
        @logfile.puts(message)
      end
    end
  end

  class BackupRestoreProgressLogger < BackupRestoreNew::Logger::BaseProgressLogger
    def initialize(message, logger)
      @message = message
      @logger = logger

      @progressbar = ProgressBar.create(
        format: " %j%%  %t | %c / %C | %E",
        title: @message,
        autofinish: false
      )
    end

    def start(max_progress)
      @progress = 0
      @max_progress = max_progress

      @progressbar.progress = @progress
      @progressbar.total = @max_progress

      log_progress
    end

    def increment
      @progress += 1
      @progressbar.increment
      log_progress if @progress % 50 == 0
    end

    def log(message, ex = nil)
      @logger.log_to_logfile(message, BackupRestoreNew::Logger::WARNING)
    end

    def success
      @progressbar.format = "%t | %c / %C | %E"
      @progressbar.title = " DONE ".green + " #{@message}"
      @progressbar.finish
    end

    def error
      @progressbar.format = "%t | %c / %C | %E"
      @progressbar.title = " FAIL ".red + " #{@message}"
      @progressbar.finish
    end

    private

    def log_progress
      @logger.log_to_logfile("#{@message} | #{@progress} / #{@max_progress}")
    end
  end
end
