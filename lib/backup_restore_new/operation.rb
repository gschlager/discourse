# frozen_string_literal: true

module BackupRestoreNew
  class OperationRunningError < RuntimeError; end

  class Operation
    RUNNING_KEY = "backup_restore_operation_is_running"
    ABORT_KEY = "backup_restore_operation_should_shutdown"

    def self.start
      if !Discourse.redis.set(RUNNING_KEY, "1", ex: 60, nx: true)
        raise BackupRestoreNew::OperationRunningError
      end

      @keep_running_thread = keep_running
      @abort_listener_thread = listen_for_abort_signal
      Rails.env.test? ? [@keep_running_thread, @abort_listener_thread] : true
    end

    def self.finish
      if @keep_running_thread
        @keep_running_thread.kill
        @keep_running_thread.join if @keep_running_thread.alive?
        @keep_running_thread = nil
      end

      Discourse.redis.del(RUNNING_KEY)

      if @abort_listener_thread
        @abort_listener_thread.join if @abort_listener_thread.alive?
        @abort_listener_thread = nil
      end
    end

    def self.running?
      !!Discourse.redis.get(RUNNING_KEY)
    end

    def self.abort!
      Discourse.redis.set(ABORT_KEY, "1")
    end

    def self.should_abort?
      !!Discourse.redis.get(ABORT_KEY)
    end

    class << self
      private

      def keep_running
        Thread.new do
          Thread.current.name = "keep_running"

          while true
            # extend the expiry by 1 minute every 30 seconds
            Discourse.redis.expire(RUNNING_KEY, 60.seconds)
            sleep(30.seconds)
          end
        end
      end

      def listen_for_abort_signal
        Discourse.redis.del(ABORT_KEY)

        Thread.new do
          Thread.current.name = "abort_listener"

          while running?
            exit if should_abort?
            sleep(0.1)
          end
        end
      end
    end
  end
end
