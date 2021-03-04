# frozen_string_literal: true

module BackupRestore
  class RunningSidekiqJobsError < RuntimeError
    def initialize
      super("Sidekiq did not finish running all the jobs in the allowed time!")
    end
  end

  class SystemInterface
    OPERATION_RUNNING_KEY = "backup_restore_operation_is_running"
    LOGS_MESSAGE_ID_KEY = "start_logs_message_id"

    delegate :log, to: :@logger, private: true

    def initialize(logger)
      # @type [Logger]
      @logger = logger

      @current_db = RailsMultisite::ConnectionManagement.current_db
      @readonly_mode_was_enabled = Discourse.readonly_mode?
    end

    def enable_readonly_mode
      return if @readonly_mode_was_enabled

      log "Enabling readonly mode..."
      Discourse.enable_readonly_mode
    rescue => ex
      log "Something went wrong while enabling readonly mode", ex
    end

    def disable_readonly_mode
      return if @readonly_mode_was_enabled

      log "Disabling readonly mode..."
      Discourse.disable_readonly_mode
    rescue => ex
      log "Something went wrong while disabling readonly mode", ex
    end

    def mark_operation_as_running
      log "Marking operation as running..."

      if !Discourse.redis.set(OPERATION_RUNNING_KEY, "1", ex: 60, nx: true)
        raise BackupRestore::OperationRunningError
      end

      save_start_logs_message_id
      keep_operation_running
    end

    def mark_operation_as_finished
      log "Marking operation as finished"
      Discourse.redis.del(OPERATION_RUNNING_KEY)

      if @keep_operation_running_thread
        @keep_operation_running_thread.kill
        @keep_operation_running_thread.join
        @keep_operation_running_thread = nil
      end
    end

    def is_operation_running?
      !!Discourse.redis.get(OPERATION_RUNNING_KEY)
    end

    def listen_for_shutdown_signal
      BackupRestore.clear_shutdown_signal!

      Thread.new do
        Thread.current.name = "shutdown_wait"

        while is_operation_running?
          exit if BackupRestore.should_shutdown?
          sleep 0.1
        end
      end
    end

    def pause_sidekiq(reason)
      return if Sidekiq.paused?

      log "Pausing Sidekiq..."
      Sidekiq.pause!(reason)
    end

    def unpause_sidekiq
      return unless Sidekiq.paused?

      log "Unpausing Sidekiq..."
      Sidekiq.unpause!
    rescue => ex
      log "Something went wrong while unpausing Sidekiq.", ex
    end

    def wait_for_sidekiq
      # Wait at least 6 seconds because the data about workers is updated every 5 seconds
      # https://github.com/mperham/sidekiq/wiki/API#workers
      max_wait_seconds = 60
      wait_seconds = 6.0

      log "Waiting up to #{max_wait_seconds} seconds for Sidekiq to finish running jobs..."

      max_iterations = (max_wait_seconds / wait_seconds).ceil
      iterations = 1

      loop do
        sleep wait_seconds
        break if !sidekiq_has_running_jobs?

        iterations += 1
        raise RunningSidekiqJobsError.new if iterations > max_iterations

        log "Waiting for sidekiq to finish running jobs... ##{iterations}"
      end
    end

    def flush_redis
      ignored_keys = [SidekiqPauser::PAUSED_KEY, OPERATION_RUNNING_KEY, LOGS_MESSAGE_ID_KEY] + BackupRestore.redis_keys

      redis = Discourse.redis
      redis.scan_each(match: "*") do |key|
        redis.del(key) unless ignored_keys.include?(key)
      end
    end

    def clear_sidekiq_queues
      Sidekiq::Queue.all.each do |queue|
        queue.each { |job| delete_job_if_it_belongs_to_current_site(job) }
      end

      Sidekiq::RetrySet.new.each { |job| delete_job_if_it_belongs_to_current_site(job) }
      Sidekiq::ScheduledSet.new.each { |job| delete_job_if_it_belongs_to_current_site(job) }
      Sidekiq::DeadSet.new.each { |job| delete_job_if_it_belongs_to_current_site(job) }
    end

    protected

    def sidekiq_has_running_jobs?
      Sidekiq::Workers.new.each do |_, _, work|
        args = work&.dig("payload", "args")&.first
        current_site_id = args["current_site_id"] if args.present?

        return true if current_site_id.blank? || current_site_id == @current_db
      end

      false
    end

    def delete_job_if_it_belongs_to_current_site(job)
      job.delete if job.args.first&.fetch("current_site_id", nil) == @current_db
    end

    def keep_operation_running
      # extend the expiry by 1 minute every 30 seconds
      @keep_operation_running_thread = Thread.new do
        Thread.current.name = "keep_running"

        while true
          Discourse.redis.expire(OPERATION_RUNNING_KEY, 1.minute)
          sleep(30.seconds)
        end
      end
    end

    def save_start_logs_message_id
      id = MessageBus.last_id(BackupRestore::LOGS_CHANNEL)
      Discourse.redis.set(LOGS_MESSAGE_ID_KEY, id)
    end

    def start_logs_message_id
      Discourse.redis.get(LOGS_MESSAGE_ID_KEY).to_i
    end
  end
end
