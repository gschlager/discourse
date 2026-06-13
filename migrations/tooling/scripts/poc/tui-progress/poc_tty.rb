#!/usr/bin/env ruby
# frozen_string_literal: true

# tty-progressbar POC: drives TTY::ProgressBar::Multi from the same simulation
# harness. Unlike the other two POCs there is no render thread — the gem
# renders synchronously inside advance()/log() on the producer threads,
# throttled by its frequency option.
#
# Env knobs: POC_REPORT, POC_FPS (frequency), POC_NO_FORK as in the other POCs.

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "tty-progressbar"
  gem "json"
end

require "json"
require_relative "sim_harness"

MONO = Process::CLOCK_MONOTONIC
def mono = Process.clock_gettime(MONO)

def proc_cpu_seconds
  fields = File.read("/proc/self/stat").split
  (fields[13].to_i + fields[14].to_i) / 100.0
end

class TtySink
  attr_reader :cpu_marks, :sim_stats, :call_stats

  def initialize(frequency: 30)
    @frequency = frequency
    @multi = TTY::ProgressBar::Multi.new
    @bars = {}
    @current = Hash.new(0)
    @annotations = Hash.new { |h, k| h[k] = { warnings: 0, errors: 0 } }
    @pre_bar_notices = []
    @mutex = Mutex.new
    @cpu_marks = { run_start: cpu_mark }
    @sim_stats = nil
    # Time spent inside sink calls = overhead imposed on producer threads.
    @call_stats = { count: 0, sum: 0.0, max: 0.0 }
  end

  # tty-progressbar can't cleanly re-format a registered bar from spinner to
  # determinate mid-flight, so the counting phase is just a logged notice; the
  # bar registers when the total is known (step_started).
  def step_counting(id, title)
    notice("⠿ Calculating total for #{title}…")
  end

  def step_started(id, title, total)
    timed do
      @mutex.synchronize do
        format =
          if total
            "#{title.ljust(16)}[:bar] :percent :current/:total :elapsed:extra"
          else
            "#{title.ljust(16)}:spinner :current :elapsed:extra"
          end
        bar = @multi.register(format, total: total, width: 18, frequency: @frequency,
                                      complete: "█", incomplete: "░")
        @bars[id] = bar
        bar.advance(0, extra: "")
        @pre_bar_notices.shift.then { |n| bar.log(n) } until @pre_bar_notices.empty?
      end
    end
  end

  def step_progress(id, current, warnings, errors, _posted_at)
    timed do
      bar = @mutex.synchronize { @bars[id] }
      return unless bar
      delta = current - @current[id]
      @current[id] = current
      a = @annotations[id]
      a[:warnings] = warnings
      a[:errors] = errors
      bar.advance(delta, extra: extra_for(a)) if delta >= 0
    end
  end

  def step_finished(id, current, warnings, errors)
    timed do
      bar = @mutex.synchronize { @bars[id] }
      return unless bar
      bar.advance(current - @current[id], extra: extra_for(warnings: warnings, errors: errors))
      bar.finish
    end
  end

  def notice(text)
    timed do
      bar = @mutex.synchronize { @bars.values.last }
      if bar
        bar.log(text)
      else
        @mutex.synchronize { @pre_bar_notices << text }
      end
    end
  end

  def sim_done(stats)
    @sim_stats = stats
    @cpu_marks[:sim_done] = cpu_mark
  end

  def mark_tail = @cpu_marks[:tail_done] = cpu_mark

  private

  def cpu_mark = { cpu: proc_cpu_seconds, wall: mono }

  def extra_for(a)
    parts = []
    parts << "  ⚠ #{a[:warnings]} warnings" if a[:warnings] > 0
    parts << "  ✗ #{a[:errors]} errors" if a[:errors] > 0
    parts.join
  end

  def timed
    t0 = mono
    yield
  ensure
    dt = mono - t0
    @mutex.synchronize do
      @call_stats[:count] += 1
      @call_stats[:sum] += dt
      @call_stats[:max] = dt if dt > @call_stats[:max]
    end
  end
end

report_path = ENV.fetch("POC_REPORT", File.join(__dir__, "report.json"))
sink = TtySink.new(frequency: ENV.fetch("POC_FPS", "30").to_i)
outcome = "normal"

begin
  sink.notice("ℹ simulation started (tty-progressbar)")
  TuiPoc::Simulation.new(sink, fork_children: ENV["POC_NO_FORK"] != "1").run
  sleep 3 # idle tail; bars are finished, nothing should render
  sink.mark_tail
rescue Interrupt
  outcome = "interrupt"
end

calls = sink.call_stats
report = {
  outcome: outcome,
  loop_mode: "tty-progressbar",
  ruby: RUBY_DESCRIPTION,
  gems: %w[tty-progressbar tty-cursor tty-screen unicode-display_width strings-ansi].to_h do |g|
    [g, Gem.loaded_specs[g]&.version&.to_s]
  end,
  stdout_tty: $stdout.tty?,
  sink_call_ms: calls[:count].zero? ? nil : {
    count: calls[:count],
    avg: (calls[:sum] / calls[:count] * 1000).round(3),
    max: (calls[:max] * 1000).round(1),
  },
  cpu_phases: begin
    marks = sink.cpu_marks
    phases = {}
    if marks[:run_start] && marks[:sim_done]
      dw = marks[:sim_done][:wall] - marks[:run_start][:wall]
      dc = marks[:sim_done][:cpu] - marks[:run_start][:cpu]
      phases[:active] = { wall_s: dw.round(2), cpu_s: dc.round(2), cpu_pct: (dc / dw * 100).round(1) }
    end
    if marks[:sim_done] && marks[:tail_done]
      dw = marks[:tail_done][:wall] - marks[:sim_done][:wall]
      dc = marks[:tail_done][:cpu] - marks[:sim_done][:cpu]
      phases[:idle_tail] = { wall_s: dw.round(2), cpu_s: dc.round(2), cpu_pct: (dc / dw * 100).round(1) }
    end
    phases
  end,
  sim_stats: sink.sim_stats,
}

File.write(report_path, JSON.pretty_generate(report))
warn "INTERRUPT-PATH-OK" if outcome == "interrupt"
exit(outcome == "interrupt" ? 130 : 0)
