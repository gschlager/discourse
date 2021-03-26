# frozen_string_literal: true

module BackupRestoreNew
  module Logger
    class BaseProgressLogger
      def start(max_value); end
      def increment; end
      def log(message, ex = nil); end
    end
  end
end
