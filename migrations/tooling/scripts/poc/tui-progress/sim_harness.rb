# frozen_string_literal: true

# Renderer-agnostic simulation of a converter run. Drives a "sink" object from
# plain Ruby threads, the way the real TUI reporter will be driven by the
# converter's step scheduler. No migrations code, no rendering code in here.
#
# Sink interface (all calls may come from any thread):
#   step_started(id, title, total)              # total: Integer or nil (indeterminate)
#   step_progress(id, current, warnings, errors, posted_at)
#   step_finished(id, current, warnings, errors)
#   notice(text)
#   sim_done(stats)
module TuiPoc
  class Simulation
    MONO = Process::CLOCK_MONOTONIC

    # Staggered starts, 1-4 steps concurrent. `interval` is the producer's
    # posting period: posts is the 200 updates/sec stress producer.
    STEPS = [
      { id: :categories, title: "Categories", total: 4_281, delay: 0.0, duration: 1.5, interval: 0.1 },
      { id: :users, title: "Users", total: 312_440, delay: 0.3, duration: 3.0, interval: 0.1, warn_every: 4 },
      { id: :posts, title: "Posts", total: 1_248_776, delay: 1.0, duration: 6.0, interval: 0.005, error_at: [0.41, 0.83] },
      { id: :tags, title: "Tags", total: 10_944, delay: 1.4, duration: 2.5, interval: 0.1 },
      { id: :uploads, title: "Uploads", total: nil, after: :categories, duration: 3.0, interval: 0.1, count_to: 35_812 },
      { id: :likes, title: "Likes 🚀", total: 50_000, after: :users, duration: 2.0, interval: 0.1 },
    ].freeze

    NOTICES = [
      "Calculating max progress for posts, this may take a while…",
      "Skipped 3 users with invalid emails",
      "Index hint: post_custom_fields is missing index on (name)",
      "Re-checking orphaned uploads",
      "Slow query in tags lookup (412 ms)",
      "Checkpoint written",
    ].freeze

    def initialize(sink, fork_children: true)
      @sink = sink
      @fork_children = fork_children
      @done = Hash.new { |h, k| h[k] = Queue.new }
      @stats = { steps: {}, forks: { forked: 0, reaped: 0, fork_errors: [] } }
      @stats_mutex = Mutex.new
    end

    def run
      t0 = now
      threads = STEPS.map { |spec| Thread.new { run_step(spec) } }
      threads << Thread.new { run_notices(t0) }
      threads << Thread.new { run_forks(t0) } if @fork_children
      threads.each(&:join)
      @stats[:wall_seconds] = (now - t0).round(2)
      @sink.sim_done(@stats)
      @stats
    end

    private

    def now = Process.clock_gettime(MONO)

    def run_step(spec)
      if spec[:after]
        @done[spec[:after]].pop
      else
        sleep spec[:delay]
      end

      @sink.step_started(spec[:id], spec[:title], spec[:total])

      target = spec[:total] || spec[:count_to]
      t_start = now
      posts = 0
      warnings = 0
      errors = 0
      prev_frac = 0.0

      loop do
        frac = [(now - t_start) / spec[:duration], 1.0].min
        current = (target * frac).round
        posts += 1
        warnings += 1 if spec[:warn_every] && (posts % spec[:warn_every]).zero?
        spec[:error_at]&.each { |f| errors += 1 if prev_frac < f && frac >= f }
        prev_frac = frac
        @sink.step_progress(spec[:id], current, warnings, errors, now)
        break if frac >= 1.0
        sleep spec[:interval]
      end

      elapsed = now - t_start
      @sink.step_finished(spec[:id], target, warnings, errors)
      @stats_mutex.synchronize do
        @stats[:steps][spec[:id]] = {
          posts: posts,
          planned_posts: (spec[:duration] / spec[:interval]).round,
          achieved_rate: (posts / elapsed).round(1),
          planned_rate: (1.0 / spec[:interval]).round(1),
          seconds: elapsed.round(2),
        }
      end
      @done[spec[:id]].push(true)
    end

    def run_notices(t0)
      NOTICES.each_with_index do |text, i|
        sleep 1.5
        @sink.notice("ℹ #{text}")
        break if now - t0 > 11
      end
    end

    # The ForkManager-shaped scenario: while bars animate, fork a batch of
    # children that sleep and exit; reap them from this (non-main) thread.
    def run_forks(t0)
      sleep 4.0
      pids = []
      4.times do |i|
        pid = Process.fork do
          # Worker child: inherits the raw-mode terminal and the Go runtime's
          # memory/signal dispositions, uses neither. exit! skips at_exit.
          sleep 1.0
          exit!(0)
        end
        pids << pid
        @stats[:forks][:forked] += 1
      rescue => e
        @stats[:forks][:fork_errors] << "fork: #{e.class}: #{e.message}"
      end
      @sink.notice("ℹ forked #{pids.size} worker children: #{pids.join(", ")}")

      pids.each do |pid|
        _, status = Process.wait2(pid)
        @stats[:forks][:reaped] += 1
        @stats[:forks][:fork_errors] << "pid #{pid} status #{status.exitstatus}" unless status.exitstatus == 0
      rescue => e
        @stats[:forks][:fork_errors] << "wait #{pid}: #{e.class}: #{e.message}"
      end
      @sink.notice("ℹ reaped #{@stats[:forks][:reaped]} worker children")
    end
  end
end
