#!/usr/bin/env ruby
# frozen_string_literal: true

# ANSI-fallback POC: hand-rolled cursor-up + line-rewrite live region with
# permanent lines (notices, finished steps) scrolling above it. Same simulation
# harness as poc_bubbletea.rb, zero gem dependencies (stdlib only).
#
# Env knobs:
#   POC_REPORT=path   where to write the JSON report (default report.json)
#   POC_FPS=n         frames per second (default 30)
#   POC_NO_FORK=1     skip the mid-run fork scenario

require "json"
require "io/console"
require "reline"
require_relative "sim_harness"

MONO = Process::CLOCK_MONOTONIC
def mono = Process.clock_gettime(MONO)

def proc_cpu_seconds
  fields = File.read("/proc/self/stat").split
  (fields[13].to_i + fields[14].to_i) / 100.0
end

module Ansi
  RESET = "\e[0m"
  GREEN = "\e[32m"
  YELLOW = "\e[33m"
  RED = "\e[31m"
  DIM = "\e[90m"
  BAR_FULL = "\e[38;2;117;113;249m"
  BAR_EMPTY = "\e[38;2;96;96;96m"
  EL = "\e[K"     # erase to end of line
  EL_ALL = "\e[2K"
  ERASE_BELOW = "\e[J" # erase from cursor to end of screen
  HIDE_CURSOR = "\e[?25l"
  SHOW_CURSOR = "\e[?25h"

  def self.up(n) = "\e[#{n}A"

  def self.width(str)
    str.gsub(/\e\[[0-9;]*m/, "").grapheme_clusters.sum { |c| Reline::Unicode.get_mbchar_width(c) }
  end

  # ANSI-aware truncation to a visible width (keeps SGR sequences intact).
  def self.truncate(line, max)
    return line if width(line) <= max
    out = +""
    used = 0
    line.scan(/\e\[[0-9;]*m|\X/) do |tok|
      if tok.start_with?("\e")
        out << tok
        next
      end
      w = Reline::Unicode.get_mbchar_width(tok)
      break if used + w > max
      out << tok
      used += w
    end
    out << RESET
  end
end

# Implements the sim harness sink interface. Producers push events into a
# Queue; a render thread drains it at frame rate and repaints. Terminal output
# is therefore frame-rate bound by construction.
class AnsiRenderer
  SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze

  attr_reader :latency, :frames, :writes, :cpu_marks, :sim_stats

  def initialize(fps: 30)
    @fps = fps
    @queue = Thread::Queue.new
    @steps = {}
    @pending_permanent = []
    @live_count = 0
    @done = false
    @latency = { count: 0, sum: 0.0, min: nil, max: nil, over_100ms: 0 }
    @frames = 0
    @writes = 0
    @cpu_marks = {}
    @sim_stats = nil
    @resize_pending = false
    @cols = ($stdout.winsize[1] rescue 80)
  end

  # --- sink interface (called from producer threads) ---
  def step_started(id, title, total) = @queue << [:started, id, title, total]
  def step_progress(id, current, warnings, errors, posted_at) = @queue << [:progress, id, current, warnings, errors, posted_at]
  def step_finished(id, current, warnings, errors) = @queue << [:finished, id, current, warnings, errors]
  def notice(text) = @queue << [:notice, text]
  def sim_done(stats) = @queue << [:sim_done, stats]

  # --- render loop (runs on the main thread) ---
  def run
    mark_cpu(:run_start)
    @winch_prev = Signal.trap("WINCH") { @resize_pending = true }
    $stdout.write(Ansi::HIDE_CURSOR)
    frame = 1.0 / @fps
    idle_deadline = nil

    until idle_deadline && mono >= idle_deadline
      t0 = mono
      gc0 = GC.count
      drain_queue
      t_drain = mono
      if @done && idle_deadline.nil?
        mark_cpu(:sim_done)
        idle_deadline = mono + 3.0 # idle tail for CPU measurement
      end
      if @resize_pending
        @resize_pending = false
        @cols = ($stdout.winsize[1] rescue @cols)
        @last_live = nil # force a repaint at the new width
        # Reclaim what we provably can: after a resize the old region is at
        # least @live_count physical rows tall (rewrapping never shrinks it),
        # so moving up live_count-1 rows stays within our own rows. Erase from
        # there to the end of the screen and repaint. Pure grows and
        # non-reflowing terminals lose the whole stale region; reflowing
        # shrinks can leave fragments of the topmost lines.
        if @live_count > 0
          out = +""
          out << Ansi.up(@live_count - 1) if @live_count > 1
          out << "\r" << Ansi::ERASE_BELOW
          $stdout.write(out)
          @live_count = 0
        end
      end
      repaint
      t_paint = mono
      if t_paint - t0 > 0.05
        (@slow_frames ||= []) << { at: (t0 - @cpu_marks.dig(:run_start, :wall)).round(2),
                                   drain_ms: ((t_drain - t0) * 1000).round(1),
                                   paint_ms: ((t_paint - t_drain) * 1000).round(1),
                                   gc_runs: GC.count - gc0 }
      end
      budget = frame - (mono - t0)
      sleep(budget) if budget > 0
    end
    mark_cpu(:tail_done)
  ensure
    cleanup
  end

  def cleanup
    return if @cleaned
    @cleaned = true
    Signal.trap("WINCH", @winch_prev || "DEFAULT")
    # Flush pending permanents and drop the live region so the final state
    # persists in the scrollback.
    drain_queue
    repaint(final: true)
    $stdout.write(Ansi::SHOW_CURSOR)
    $stdout.flush
  end

  private

  def mark_cpu(name)
    @cpu_marks[name] = { cpu: proc_cpu_seconds, wall: mono }
  end

  def drain_queue
    until @queue.empty?
      event = @queue.pop(true)
      case event[0]
      when :started
        _, id, title, total = event
        @steps[id] = { title: title, total: total, current: 0, warnings: 0,
                       errors: 0, state: :running, started_at: mono, projection: 0.0 }
      when :progress
        _, id, current, warnings, errors, posted_at = event
        record_latency(mono - posted_at)
        if (s = @steps[id])
          s[:current] = current
          s[:warnings] = warnings
          s[:errors] = errors
          # Same smoothing as ExtendedProgressBar: ruby-progressbar's
          # SmoothedAverage.calculate with strength 0.5 over absolute progress.
          s[:projection] = current * 0.5 + s[:projection] * 0.5
        end
      when :finished
        _, id, current, warnings, errors = event
        if (s = @steps[id])
          s.merge!(current: current, warnings: warnings, errors: errors, state: :done)
          @pending_permanent << finished_line(s, mono - s[:started_at])
        end
      when :notice
        @pending_permanent << "#{Ansi::DIM}#{event[1]}#{Ansi::RESET}"
      when :sim_done
        @sim_stats = event[1]
        @done = true
      end
    end
  rescue ThreadError
    nil
  end

  # The live-region protocol: cursor parks at column 0 of the last live line.
  # Each frame: cursor-up to the top of the region, emit any new permanent
  # lines (they push the region down and scroll into normal terminal history),
  # rewrite all live lines, erase leftovers if the region shrank.
def repaint(final: false)
  tr0 = mono
  permanent = @pending_permanent
  @pending_permanent = []
  live = final ? [] : @steps.values.select { |s| s[:state] == :running }.map { |s| running_line(s) }
  tr1 = mono
  (@slow_sections ||= []) << { sect: "live_build", ms: ((tr1 - tr0) * 1000).round(1) } if tr1 - tr0 > 0.05

    return if permanent.empty? && live.empty? && @live_count.zero?
    return if !final && permanent.empty? && live == @last_live

tr2 = mono
out = +""
out << Ansi.up(@live_count - 1) if @live_count > 1
out << "\r"

    permanent.each { |line| out << Ansi::EL_ALL << fit(line) << "\r\n" }
    live.each_with_index do |line, i|
      out << Ansi::EL_ALL << fit(line)
      out << "\r\n" if i < live.size - 1
    end

    leftover = @live_count - live.size
    leftover = 0 if leftover.negative?
    if leftover > 0
      leftover.times { out << "\r\n" << Ansi::EL_ALL }
      out << Ansi.up(leftover) unless final
    end
    out << "\r"

tw0 = mono
$stdout.write(out)
tw1 = mono
$stdout.flush
tw2 = mono
if tw2 - tw0 > 0.05
  (@slow_writes ||= []) << { build_done_at: tw0.round(3), write_ms: ((tw1 - tw0) * 1000).round(1), flush_ms: ((tw2 - tw1) * 1000).round(1), bytes: out.bytesize }
end
    @writes += 1
    @frames += 1
    @live_count = live.size
    @last_live = live
  end

  # Two columns short of the window: WINCH arrives in small steps during a
  # window drag, and lines that never exceed the shrunken width never wrap,
  # so the resize reclaim stays exact. Only a jump wider than the margin can
  # still wrap a line.
  def fit(line)
    Ansi.truncate(line, [@cols - 2, 8].max)
  end

  def record_latency(lat)
    l = @latency
    l[:count] += 1
    l[:sum] += lat
    l[:min] = lat if l[:min].nil? || lat < l[:min]
    l[:max] = lat if l[:max].nil? || lat > l[:max]
    if lat > 0.1
      l[:over_100ms] += 1
      start = @cpu_marks.dig(:run_start, :wall)
      (l[:spike_offsets_s] ||= []) << (mono - start).round(2) if start
    end
  end

  def title_col(title, prefix)
    pad = 16 - Ansi.width(title)
    "#{prefix}#{title}#{" " * [pad, 1].max}"
  end

  def bar(pct, width = 13)
    filled = (pct * width).round
    "#{Ansi::BAR_FULL}#{"█" * filled}#{Ansi::BAR_EMPTY}#{"░" * (width - filled)}#{Ansi::RESET} #{format("%3.0f%%", pct * 100)}"
  end

  def running_line(s)
    line = +title_col(s[:title], "  ")
    if s[:total]
      pct = [s[:current].to_f / s[:total], 1.0].min
      line << bar(pct) << "  #{fmt_count(s[:current])}/#{fmt_count(s[:total])}"
    else
      line << "#{SPINNER[(mono * 12).to_i % SPINNER.size]} #{fmt_count(s[:current])}"
    end
    elapsed = mono - s[:started_at]
    line << "  #{fmt_duration(elapsed)}"
    if s[:total] && s[:projection] > 0 && elapsed > 1
      remaining = [elapsed * (s[:total] / s[:projection] - 1), 0].max
      line << "#{Ansi::DIM}  ETA #{fmt_duration(remaining)}#{Ansi::RESET}"
    end
    line << "#{Ansi::YELLOW}  ⚠ #{s[:warnings]} warnings#{Ansi::RESET}" if s[:warnings] > 0
    line << "#{Ansi::RED}  ✗ #{s[:errors]} errors#{Ansi::RESET}" if s[:errors] > 0
    line
  end

  def finished_line(s, elapsed)
    line = +title_col(s[:title], "#{Ansi::GREEN}✓#{Ansi::RESET} ")
    line << (s[:total] ? "#{fmt_count(s[:current])}/#{fmt_count(s[:total])}" : fmt_count(s[:current]))
    line << "#{Ansi::DIM}  #{fmt_duration(elapsed)}#{Ansi::RESET}"
    line << "#{Ansi::YELLOW}  ⚠ #{s[:warnings]} warnings#{Ansi::RESET}" if s[:warnings] > 0
    line << "#{Ansi::RED}  ✗ #{s[:errors]} errors#{Ansi::RESET}" if s[:errors] > 0
    line
  end

  def fmt_count(n) = n.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")
  def fmt_duration(seconds) = format("%d:%02d", seconds / 60, seconds % 60)
end

# Graceful degradation for dumb/non-terminals (CI logs, RubyMine run console,
# piped output): plain line-based output, no cursor movement, no live region.
# Progress is logged once per decile so CI logs stay readable.
class PlainRenderer
  attr_reader :sim_stats

  def initialize
    @steps = {}
    @mutex = Mutex.new # whole lines only, even with many producer threads
    @sim_stats = nil
    $stdout.sync = true
  end

  def step_started(id, title, total)
    @mutex.synchronize do
      @steps[id] = { title: title, total: total, started_at: mono, decile: 0 }
      puts "#{title} started#{" (#{fmt_count(total)} items)" if total}"
    end
  end

  def step_progress(id, current, warnings, errors, _posted_at)
    @mutex.synchronize do
      s = @steps[id]
      next unless s && s[:total]
      decile = [current * 10 / s[:total], 10].min
      next unless decile > s[:decile]
      s[:decile] = decile
      puts "#{s[:title]} #{decile * 10}% (#{fmt_count(current)}/#{fmt_count(s[:total])})"
    end
  end

  def step_finished(id, current, warnings, errors)
    @mutex.synchronize do
      s = @steps[id]
      next unless s
      line = +"✓ #{s[:title]} #{fmt_count(current)} in #{fmt_duration(mono - s[:started_at])}"
      line << ", #{warnings} warnings" if warnings > 0
      line << ", #{errors} errors" if errors > 0
      puts line
    end
  end

  def notice(text) = @mutex.synchronize { puts text }
  def sim_done(stats) = @sim_stats = stats

  private

  def fmt_count(n) = n.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")
  def fmt_duration(seconds) = format("%d:%02d", seconds / 60, seconds % 60)
end

# --- Wiring ------------------------------------------------------------------

report_path = ENV.fetch("POC_REPORT", File.join(__dir__, "report.json"))

# The selection ladder the real reporter setup will use: full TUI only on a
# real, capable terminal; otherwise plain line output.
plain_reason =
  if !$stdout.tty?
    "stdout is not a tty"
  elsif ENV["TERM"].to_s.empty? || ENV["TERM"] == "dumb"
    "TERM=#{ENV["TERM"].inspect}"
  end

if plain_reason
  warn "poc_ansi: plain output mode (#{plain_reason})"
  renderer = PlainRenderer.new
  outcome = "plain_mode"
  begin
    renderer.notice("simulation started (plain mode: #{plain_reason})")
    TuiPoc::Simulation.new(renderer, fork_children: ENV["POC_NO_FORK"] != "1").run
  rescue Interrupt
    outcome = "plain_interrupt"
  end
  File.write(report_path, JSON.pretty_generate(outcome: outcome, reason: plain_reason,
                                               sim_stats: renderer.sim_stats))
  exit 0
end

def stty_state
  state = `stty -g 2>/dev/null`.strip
  state.empty? ? nil : state
end

renderer = AnsiRenderer.new(fps: ENV.fetch("POC_FPS", "30").to_i)
stty_before = stty_state
outcome = "normal"

begin
  renderer.notice("ℹ simulation started (ansi fallback, fps=#{renderer.instance_variable_get(:@fps)})")
  sim = Thread.new do
    sleep 0.2
    TuiPoc::Simulation.new(renderer, fork_children: ENV["POC_NO_FORK"] != "1").run
  end
  sim.report_on_exception = false
  renderer.run # main thread renders; Ctrl-C raises Interrupt right here
rescue Interrupt
  outcome = "interrupt"
  renderer.cleanup
end

stty_after = stty_state

lat = renderer.latency
report = {
  outcome: outcome,
  loop_mode: "ansi",
  ruby: RUBY_DESCRIPTION,
  gems: {},
  stdout_tty: true,
  lost_messages: 0,
  latency_ms: lat[:count].zero? ? nil : {
    count: lat[:count],
    min: (lat[:min] * 1000).round(2),
    avg: (lat[:sum] / lat[:count] * 1000).round(2),
    max: (lat[:max] * 1000).round(2),
    over_100ms: lat[:over_100ms],
    spike_offsets_s: lat[:spike_offsets_s],
  },
  slow_frames: renderer.instance_variable_get(:@slow_frames),
  slow_writes: renderer.instance_variable_get(:@slow_writes),
  slow_sections: renderer.instance_variable_get(:@slow_sections),
  frames: renderer.frames,
  writes: renderer.writes,
  cpu_phases: begin
    marks = renderer.cpu_marks
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
  sim_stats: renderer.sim_stats,
  stty_restored: stty_before && stty_after ? stty_before == stty_after : nil,
  widths: { "✓" => Ansi.width("✓"), "⚠" => Ansi.width("⚠"), "✗" => Ansi.width("✗"),
            "🚀" => Ansi.width("🚀"), "Likes 🚀" => Ansi.width("Likes 🚀") },
}

File.write(report_path, JSON.pretty_generate(report))
warn "INTERRUPT-PATH-OK" if outcome == "interrupt"
exit(outcome == "interrupt" ? 130 : 0)
