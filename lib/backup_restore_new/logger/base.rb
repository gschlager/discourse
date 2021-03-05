# frozen_string_literal: true

module BackupRestoreNew
  module Logger
    INFO = :info
    WARNING = :warning
    ERROR = :error

    class Base
      def log_event(event); end

      def log_task(message)
        log(message)
        yield
      end

      def log(message, level: Logger::INFO)
        raise NotImplementedError
      end

      def log_warning(message, ex = nil)
        log_with_exception(message, ex, Logger::WARNING)
      end

      def log_error(message, ex)
        log_with_exception(message, ex, Logger::ERROR)
      end

      protected

      def create_timestamp
        Time.now.utc.strftime("%Y-%m-%d %H:%M:%S")
      end

      def log_with_exception(message, ex, level)
        log(message, level)
        log(format_exception(ex), level) if ex
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
