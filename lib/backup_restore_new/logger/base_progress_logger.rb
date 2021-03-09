# frozen_string_literal: true

module BackupRestoreNew
  module Logger
    class BaseProgressLogger
      def max_progress=(value); end
      def increment; end
    end
  end
end
