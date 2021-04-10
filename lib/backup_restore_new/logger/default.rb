# frozen_string_literal: true

module BackupRestoreNew
  module Logger
    class Default < Base
      def initialize(user_id, client_id)
        @user_id = user_id
        @client_id = client_id
        @logs = []
      end

      # Events are used by the UI, so we need to publish it via MessageBus.
      def log_event(event)
        publish_log(event, create_timestamp)
      end

      def log(message, level: Logger::INFO)
        timestamp = create_timestamp
        publish_log(message, timestamp)
        save_log(message, timestamp)
      end

      private

      def publish_log(message, timestamp)
        data = { timestamp: timestamp, operation: "restore", message: message }
        MessageBus.publish(BackupRestore::LOGS_CHANNEL, data, user_ids: [@user_id], client_ids: [@client_id])
      end

      def save_log(message, timestamp)
        @logs << "[#{timestamp}] #{message}"
      end
    end
  end
end
