#!/usr/bin/env ruby
# frozen_string_literal: true

# Charm-ruby (bubbletea/bubbles/lipgloss) POC for the converter's multi-step
# progress display. Throwaway code — see FINDINGS.md for the verdict.
#
# Env knobs:
#   POC_LOOP=paced|stock  loop strategy (default paced; stock = gem's run_loop)
#   POC_PUTS=1            emit notices via Bubbletea.puts instead of in-view
#   POC_NO_FORK=1         skip the mid-run fork scenario
#   POC_REPORT=path       where to write the JSON report (default report.json)
#   POC_FPS=n             frames per second (default 30)

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "bubbletea"
  gem "bubbles"
  gem "lipgloss"
  gem "json"
end

require "json"
require_relative "sim_harness"

MONO = Process::CLOCK_MONOTONIC
def mono = Process.clock_gettime(MONO)

def proc_cpu_seconds
  fields = File.read("/proc/self/stat").split
  (fields[13].to_i + fields[14].to_i) / 100.0 # utime + stime in USER_HZ (100)
end

# --- Messages: the converter-thread -> TUI wire format ----------------------

class StepStartedMsg < Bubbletea::Message
  attr_reader :id, :title, :total
  def initialize(id, title, total)
    super()
    @id, @title, @total = id, title, total
  end
end

class StepProgressMsg < Bubbletea::Message
  attr_reader :id, :current, :warnings, :errors, :posted_at
  def initialize(id, current, warnings, errors, posted_at)
    super()
    @id, @current, @warnings, @errors, @posted_at = id, current, warnings, errors, posted_at
  end
end

class StepFinishedMsg < Bubbletea::Message
  attr_reader :id, :current, :warnings, :errors
  def initialize(id, current, warnings, errors)
    super()
    @id, @current, @warnings, @errors = id, current, warnings, errors
  end
end

class NoticeMsg < Bubbletea::Message
  attr_reader :text
  def initialize(text)
    super()
    @text = text
  end
end

class SimDoneMsg < Bubbletea::Message
  attr_reader :stats
  def initialize(stats)
    super()
    @stats = stats
  end
end

class TailDoneMsg < Bubbletea::Message; end

# --- Sink adapter: harness threads -> Runner#send (Program.Send equivalent) -

class BubbleteaSink
  attr_reader :sent

  def initialize(runner)
    @runner = runner
    @sent = Hash.new(0)
    @mutex = Mutex.new
  end

  def step_started(id, title, total) = post(StepStartedMsg.new(id, title, total))
  def step_progress(id, current, warnings, errors, posted_at) = post(StepProgressMsg.new(id, current, warnings, errors, posted_at))
  def step_finished(id, current, warnings, errors) = post(StepFinishedMsg.new(id, current, warnings, errors))
  def notice(text) = post(NoticeMsg.new(text))
  def sim_done(stats) = post(SimDoneMsg.new(stats))

  private

  def post(msg)
    @mutex.synchronize { @sent[msg.class.name] += 1 }
    @runner.send(msg)
  end
end

# --- The model ---------------------------------------------------------------

class ConverterModel
  include Bubbletea::Model

  SPINNER = %w[⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏].freeze
  IDLE_TAIL = 3.0

  attr_reader :received, :latency, :interrupted, :cpu_marks, :view_calls,
              :resize_events, :last_size, :sim_stats

  def initialize(puts_mode: false)
    @puts_mode = puts_mode
    @steps = {} # id => {title:, total:, current:, warnings:, errors:, state:, started_at:}
    @permanent = [] # frozen rendered lines: notices + finished steps, in event order
    @received = Hash.new(0)
    @latency = { count: 0, sum: 0.0, min: nil, max: nil, over_100ms: 0 }
    @interrupted = false
    @cpu_marks = {}
    @view_calls = 0
    @resize_events = 0
    @last_size = nil
    @sim_stats = nil

    @green = Lipgloss::Style.new.foreground("2")
    @yellow = Lipgloss::Style.new.foreground("3")
    @red = Lipgloss::Style.new.foreground("1")
    @dim = Lipgloss::Style.new.foreground("8")
    @bars = Hash.new { |h, k| h[k] = Bubbles::Progress.new(width: 18) }
  end

  def init
    mark_cpu(:run_start)
    [self, nil]
  end

  def update(message)
    @received[message.class.name] += 1 if message.is_a?(Bubbletea::Message)

    case message
    when Bubbletea::KeyMessage
      if message.to_s == "ctrl+c"
        @interrupted = true
        return [self, Bubbletea.quit]
      end
    when Bubbletea::WindowSizeMessage
      @resize_events += 1
      @last_size = [message.width, message.height]
    when StepStartedMsg
      @steps[message.id] = {
        title: message.title, total: message.total, current: 0,
        warnings: 0, errors: 0, state: :running, started_at: mono,
      }
    when StepProgressMsg
      record_latency(mono - message.posted_at)
      if (s = @steps[message.id])
        s[:current] = message.current
        s[:warnings] = message.warnings
        s[:errors] = message.errors
      end
    when StepFinishedMsg
      if (s = @steps[message.id])
        s[:current] = message.current
        s[:warnings] = message.warnings
        s[:errors] = message.errors
        s[:state] = :done
        @permanent << finished_line(s, mono - s[:started_at])
      end
    when NoticeMsg
      if @puts_mode
        return [self, Bubbletea.puts(message.text)]
      else
        @permanent << @dim.render(message.text)
      end
    when SimDoneMsg
      @sim_stats = message.stats
      mark_cpu(:sim_done)
      return [self, Bubbletea.tick(IDLE_TAIL) { TailDoneMsg.new }]
    when TailDoneMsg
      mark_cpu(:tail_done)
      return [self, Bubbletea.quit]
    end

    [self, nil]
  end

  def view
    @view_calls += 1
    lines = []
    lines.concat(@permanent)
    @steps.each_value do |s|
      lines << running_line(s) if s[:state] == :running
    end
    lines << @dim.render("(running…)") if lines.empty?
    lines.join("\n")
  end

  private

  def mark_cpu(name)
    @cpu_marks[name] = { cpu: proc_cpu_seconds, wall: mono }
  end

  def record_latency(lat)
    l = @latency
    l[:count] += 1
    l[:sum] += lat
    l[:min] = lat if l[:min].nil? || lat < l[:min]
    l[:max] = lat if l[:max].nil? || lat > l[:max]
    l[:over_100ms] += 1 if lat > 0.1
  end

  def title_col(title, prefix)
    pad = 16 - Lipgloss.width(title)
    "#{prefix}#{title}#{" " * [pad, 1].max}"
  end

  def running_line(s)
    elapsed = fmt_duration(mono - s[:started_at])
    line = +title_col(s[:title], "  ")
    if s[:total]
      pct = s[:current].to_f / s[:total]
      line << @bars[s[:title]].view_as(pct)
      line << "  #{fmt_count(s[:current])}/#{fmt_count(s[:total])}"
    else
      frame = SPINNER[(mono * 12).to_i % SPINNER.size]
      line << "#{frame} #{fmt_count(s[:current])}"
    end
    line << "  #{elapsed}"
    line << @yellow.render("  ⚠ #{s[:warnings]} warnings") if s[:warnings] > 0
    line << @red.render("  ✗ #{s[:errors]} errors") if s[:errors] > 0
    line
  end

  def finished_line(s, elapsed)
    line = +title_col(s[:title], "#{@green.render("✓")} ")
    line << if s[:total]
      "#{fmt_count(s[:current])}/#{fmt_count(s[:total])}"
    else
      fmt_count(s[:current])
    end
    line << @dim.render("  #{fmt_duration(elapsed)}")
    line << @yellow.render("  ⚠ #{s[:warnings]} warnings") if s[:warnings] > 0
    line << @red.render("  ✗ #{s[:errors]} errors") if s[:errors] > 0
    line
  end

  def fmt_count(n) = n.to_s.gsub(/\B(?=(\d{3})+(?!\d))/, ",")

  def fmt_duration(seconds)
    format("%d:%02d", seconds / 60, seconds % 60)
  end
end

# --- Paced runner: the GVL workaround ----------------------------------------
# The stock run_loop blocks the whole VM in poll_event(10ms) every iteration
# (the C extension never releases the GVL). This loop polls input with a 1ms
# timeout once per frame and spends the rest of the frame in Ruby sleep, which
# releases the GVL for producer threads.

class PacedRunner < Bubbletea::Runner
  def run_loop
    frame = 1.0 / options[:fps]
    while @running
      frame_start = Time.now
      check_resize
      process_pending_messages
      if (event = @program.poll_event(1))
        message = Bubbletea.parse_event(event)
        handle_message(message) if message
      end
      process_ticks
      render
      budget = frame - (Time.now - frame_start)
      sleep(budget) if budget > 0
    end
  end
end

# --- Wiring ------------------------------------------------------------------

loop_mode = ENV.fetch("POC_LOOP", "paced")
fps = ENV.fetch("POC_FPS", "30").to_i
report_path = ENV.fetch("POC_REPORT", File.join(__dir__, "report.json"))

def stty_state
  state = `stty -g 2>/dev/null`.strip
  state.empty? ? nil : state
rescue Errno::ENOENT
  nil
end

model = ConverterModel.new(puts_mode: ENV["POC_PUTS"] == "1")
runner_class = loop_mode == "stock" ? Bubbletea::Runner : PacedRunner
runner = runner_class.new(model, fps: fps)
sink = BubbleteaSink.new(runner)

stty_before = stty_state
outcome = "normal"
sim_thread = nil

begin
  runner.send(NoticeMsg.new("ℹ simulation started (loop=#{loop_mode}, fps=#{fps})"))
  sim_thread = Thread.new do
    sleep 0.2 # let the runner enter its loop first
    TuiPoc::Simulation.new(sink, fork_children: ENV["POC_NO_FORK"] != "1").run
  end
  sim_thread.report_on_exception = false

  runner.run # blocks until quit (sim done + idle tail, or ctrl+c)

  raise Interrupt if model.interrupted # converter's SignalException path
rescue Interrupt
  outcome = "interrupt"
end

stty_after = stty_state

lat = model.latency
report = {
  outcome: outcome,
  loop_mode: loop_mode,
  fps: fps,
  ruby: RUBY_DESCRIPTION,
  gems: %w[bubbletea bubbles lipgloss harmonica].to_h { |g| [g, Gem.loaded_specs[g]&.version&.to_s] },
  stdout_tty: $stdout.tty?,
  terminal_size: model.last_size,
  resize_events: model.resize_events,
  sent: sink.sent,
  received: model.received.slice(*sink.sent.keys),
  lost_messages: sink.sent.sum { |k, v| v - model.received[k] },
  latency_ms: lat[:count].zero? ? nil : {
    count: lat[:count],
    min: (lat[:min] * 1000).round(2),
    avg: (lat[:sum] / lat[:count] * 1000).round(2),
    max: (lat[:max] * 1000).round(2),
    over_100ms: lat[:over_100ms],
  },
  view_calls: model.view_calls,
  cpu_phases: begin
    marks = model.cpu_marks
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
  sim_stats: model.sim_stats,
  stty_restored: stty_before && stty_after ? stty_before == stty_after : nil,
  lipgloss_sample: Lipgloss::Style.new.foreground("3").render("x").inspect,
  widths: { "✓" => Lipgloss.width("✓"), "⚠" => Lipgloss.width("⚠"),
            "✗" => Lipgloss.width("✗"), "🚀" => Lipgloss.width("🚀"),
            "Likes 🚀" => Lipgloss.width("Likes 🚀") },
}

File.write(report_path, JSON.pretty_generate(report))
warn "INTERRUPT-PATH-OK" if outcome == "interrupt"
exit(outcome == "interrupt" ? 130 : 0)
