# frozen_string_literal: true

module BackupRestoreNew
  class OperationRunningError < RuntimeError; end

  class Operation
    KEY = "backup_restore_operation_is_running"

    def self.start
      if !Discourse.redis.set(KEY, "1", ex: 60, nx: true)
        raise BackupRestoreNew::OperationRunningError
      end

      @thread = Thread.new do
        Thread.current.name = "keep_running"

        while true
          # extend the expiry by 1 minute every 30 seconds
          Discourse.redis.expire(KEY, 60.seconds)
          sleep(30.seconds)
        end
      end
    end

    def self.finish
      if @thread
        @thread.kill
        @thread.join
        @thread = nil
      end

      Discourse.redis.del(KEY)
    end

    def self.running?
      !!Discourse.redis.get(KEY)
    end
  end
end
