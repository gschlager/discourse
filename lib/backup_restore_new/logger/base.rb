# frozen_string_literal: true

module BackupRestoreNew
  module Logger
    INFO = :info
    WARNING = :warning
    ERROR = :error

    class Base
      attr_reader :logs

      def initialize
        @logs = []
      end

      def log_event(event); end

      def log_step(message, with_progress: false)
        log(message)

        if with_progress
          yield(BaseProgressLogger.new)
        else
          yield
        end
      end

      def log(message, level: Logger::INFO)
        raise NotImplementedError
      end

      def log_warning(message, ex = nil)
        log_with_exception(message, ex, Logger::WARNING)
      end

      def log_error(message, ex = nil)
        log_with_exception(message, ex, Logger::ERROR)
      end

      private

      def create_timestamp
        Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
      end

      def log_with_exception(message, ex, level)
        log(message, level: level)
        log(format_exception(ex), level: level) if ex
      end

      def format_exception(ex)
        <<~MSG
          EXCEPTION: #{ex.message}
          Backtrace:
          \t#{format_backtrace(ex)}
        MSG
      end

      def format_backtrace(ex)
        ex.backtrace.join("\n\t")
      end
    end
  end
end
