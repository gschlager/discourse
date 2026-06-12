# frozen_string_literal: true

# Test driver: runs poc_bubbletea.rb under a PTY, schedules actions (keys,
# signals, resizes), captures raw output, reconstructs the final screen with a
# minimal ANSI interpreter, and prints a per-scenario summary.
#
# Usage: ruby pty_driver.rb [scenario ...]   (default: all)

require "pty"
require "io/console"
require "json"
require "fileutils"

POC = File.join(__dir__, "poc_bubbletea.rb")
OUT_DIR = File.join(__dir__, "out")
FileUtils.mkdir_p(OUT_DIR)

SCENARIOS = {
  "paced_full" => { cols: 110, rows: 32, env: {} },
  "stock_full" => { cols: 110, rows: 32, env: { "POC_LOOP" => "stock" } },
  "paced_ctrlc" => { cols: 110, rows: 32, env: {}, actions: [[6.0, :write, "\x03"]] },
  "paced_sigint" => { cols: 110, rows: 32, env: {}, actions: [[6.0, :signal, "INT"]] },
  "small_height" => { cols: 100, rows: 10, env: {} },
  "narrow" => { cols: 34, rows: 32, env: {} },
  "resize" => { cols: 110, rows: 32, env: {}, actions: [[5.0, :resize, [32, 60]], [8.0, :resize, [32, 110]]] },
  "puts_mode" => { cols: 110, rows: 32, env: { "POC_PUTS" => "1" } },
  "pipe" => { pipe: true, env: {} },
  # ANSI fallback POC (cooked mode: \x03 becomes a real SIGINT via the pty)
  "ansi_full" => { script: "poc_ansi.rb", cols: 110, rows: 32, env: {} },
  "ansi_ctrlc" => { script: "poc_ansi.rb", cols: 110, rows: 32, env: {}, actions: [[6.0, :write, "\x03"]] },
  "ansi_small_height" => { script: "poc_ansi.rb", cols: 100, rows: 10, env: {} },
  "ansi_narrow" => { script: "poc_ansi.rb", cols: 34, rows: 32, env: {} },
  "ansi_resize" => { script: "poc_ansi.rb", cols: 110, rows: 32, env: {}, actions: [[5.0, :resize, [32, 60]], [8.0, :resize, [32, 110]]] },
"ansi_pipe" => { script: "poc_ansi.rb", pipe: true, env: {} },
"ansi_dumb" => { script: "poc_ansi.rb", cols: 110, rows: 32, env: { "TERM" => "dumb" } },
# tty-progressbar POC
"tty_full" => { script: "poc_tty.rb", cols: 110, rows: 32, env: {} },
"tty_small_height" => { script: "poc_tty.rb", cols: 100, rows: 10, env: {} },
"tty_ctrlc" => { script: "poc_tty.rb", cols: 110, rows: 32, env: {}, actions: [[6.0, :write, "\x03"]] },
"tty_narrow" => { script: "poc_tty.rb", cols: 34, rows: 32, env: {} },
"tty_pipe" => { script: "poc_tty.rb", pipe: true, env: {} },
}.freeze

TIMEOUT = 60

# Line-based ANSI interpreter. The gem's renderer always rewrites whole lines
# (\r + content + erase-to-EOL), so tracking lines + cursor row is enough to
# reconstruct what a terminal would show. Unknown sequences are recorded.
class Screen
  attr_reader :unknown_sequences

  def initialize
    @lines = [+""]
    @row = 0
    @pending = +"" # text written since last \r on this row
    @unknown_sequences = Hash.new(0)
  end

  def feed(data)
    tokens = data.scan(/\e\[[0-9;?]*[A-Za-z]|\e[78]|\e\][^\a]*\a|\r\n|\r|\n|[^\e\r\n]+/m)
    tokens.each { |t| handle(t) }
  end

  def handle(t)
    case t
    when /\A\e\[(\d*)A\z/ then move_up(($1.empty? ? 1 : $1.to_i))
    when /\A\e\[(\d*)B\z/ then move_down(($1.empty? ? 1 : $1.to_i))
    when /\A\e\[0?K\z/ then truncate_line
    when /\A\e\[2K\z/ then @lines[@row] = +""
    when /\A\e\[\?25[lh]\z/, /\A\e\[[0-9;]*m\z/ then nil # cursor vis, SGR
    when "\r\n" then move_down(1); @pending = +"" # col 0 on the next row
    when "\r" then @pending = +""
when /\A\e\[1?G\z/ then @pending = +"" # cursor to column 1 (tty-progressbar)
when "\e7" then @saved = [@row, @pending.dup] # DECSC
when "\e8" then (@row, @pending = @saved[0], @saved[1].dup) if @saved # DECRC
    when "\n" then move_down(1)
    when /\A\e/ then @unknown_sequences[t] += 1
    else
      # Renderer writes whole lines after \r, so text replaces from line start.
      @pending << t
      @lines[@row] = @pending.dup
    end
  end

  def move_up(n)
    @row = [@row - n, 0].max
    @pending = @lines[@row].dup
  end

  def move_down(n)
    @row += n
    (@lines.size..@row).each { |i| @lines[i] = +"" }
    @pending = @lines[@row].dup
  end

  def truncate_line
    @lines[@row] = @pending.dup
  end

  def to_s
    @lines.map { |l| l.gsub(/\e\[[0-9;]*m/, "") }.join("\n")
  end
end

def run_pty_scenario(name, spec)
  report_path = File.join(OUT_DIR, "#{name}.report.json")
  env = { "POC_REPORT" => report_path, "TERM" => "xterm-256color" }.merge(spec[:env])
  File.delete(report_path) if File.exist?(report_path)

  out = +""
  first_byte_at = nil
  out_mutex = Mutex.new

  script = spec[:script] ? File.join(__dir__, spec[:script]) : POC
  master, master_w, pid = PTY.spawn(env, RbConfig.ruby, script)
  master.winsize = [spec[:rows], spec[:cols]]

  reader = Thread.new do
    loop do
      data = master.readpartial(65_536)
      out_mutex.synchronize do
        first_byte_at ||= Process.clock_gettime(Process::CLOCK_MONOTONIC)
        out << data
      end
      # Behave like a real terminal: answer cursor-position queries (Reline
      # probes ambiguous character width this way and waits for the reply).
      data.scan("\e[6n") { master_w.write("\e[1;1R") rescue nil }
    end
  rescue EOFError, Errno::EIO
  end

  actor = Thread.new do
    sleep 0.05 until first_byte_at
    t0 = first_byte_at
    (spec[:actions] || []).each do |at, kind, arg|
      delay = t0 + at - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      sleep(delay) if delay > 0
      case kind
      when :write then master_w.write(arg)
      when :signal then Process.kill(arg, pid)
      when :resize then master.winsize = arg
      end
    rescue Errno::ESRCH, Errno::EIO
    end
  end

  status = wait_with_timeout(pid, TIMEOUT)
  hang = status.nil?
  if hang
    Process.kill("KILL", pid) rescue nil
    status = Process.wait2(pid)[1] rescue nil
  end
  sleep 0.2
  reader.kill
  actor.kill
  master.close rescue nil; master_w.close rescue nil

  analyze(name, spec, out, status, hang, report_path)
end

def run_pipe_scenario(name, spec)
  report_path = File.join(OUT_DIR, "#{name}.report.json")
  env = { "POC_REPORT" => report_path, "TERM" => "xterm-256color" }.merge(spec[:env])
  out_path = File.join(OUT_DIR, "#{name}.stdout")
  err_path = File.join(OUT_DIR, "#{name}.stderr")

  script = spec[:script] ? File.join(__dir__, spec[:script]) : POC
  pid = spawn(env, RbConfig.ruby, script, in: "/dev/null", out: out_path, err: err_path)
  status = wait_with_timeout(pid, TIMEOUT)
  hang = status.nil?
  if hang
    Process.kill("KILL", pid) rescue nil
    Process.wait2(pid) rescue nil
  end

  out = File.exist?(out_path) ? File.read(out_path) : ""
  err = File.exist?(err_path) ? File.read(err_path) : ""
  puts "=== #{name}: exit=#{status&.exitstatus.inspect} hang=#{hang} stdout=#{out.bytesize}B stderr=#{err.bytesize}B"
  puts "  stderr head: #{err.lines.first(3).map(&:strip).join(" | ")}" unless err.empty?
  puts "  report: #{summarize_report(report_path)}"
end

def wait_with_timeout(pid, timeout)
  deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    done, status = Process.wait2(pid, Process::WNOHANG)
    return status if done
    sleep 0.2
  end
  nil
rescue Errno::ECHILD
  nil
end

def analyze(name, spec, out, status, hang, report_path)
  File.binwrite(File.join(OUT_DIR, "#{name}.raw"), out)

  screen = Screen.new
  screen.feed(out)
  File.write(File.join(OUT_DIR, "#{name}.screen.txt"), screen.to_s)

  writes = out.scan(/\e\[\d*A/).size
  sgr_count = out.scan(/\e\[[0-9;]+m/).size
  cursor_restored = out.include?("\e[?25h")
  tail = out[-200..] || out

  puts "=== #{name}: exit=#{status&.exitstatus.inspect}#{" sig=#{status.termsig}" if status&.signaled?} hang=#{hang}"
  puts "  raw=#{out.bytesize}B cursor_up_writes=#{writes} sgr_seqs=#{sgr_count} cursor_restored=#{cursor_restored} show_cursor_in_tail=#{tail.include?("\e[?25h")}"
  puts "  unknown_seqs: #{screen.unknown_sequences.inspect}" unless screen.unknown_sequences.empty?
  puts "  report: #{summarize_report(report_path)}"
end

def summarize_report(path)
  return "MISSING" unless File.exist?(path)
  r = JSON.parse(File.read(path))
  parts = []
  parts << "outcome=#{r["outcome"]}"
  parts << "lost=#{r["lost_messages"]}"
  parts << "lat=#{r.dig("latency_ms", "avg")}ms avg / #{r.dig("latency_ms", "max")}ms max (#{r.dig("latency_ms", "over_100ms")} >100ms)"
  parts << "cpu active=#{r.dig("cpu_phases", "active", "cpu_pct")}% idle=#{r.dig("cpu_phases", "idle_tail", "cpu_pct")}%"
  parts << "stty_restored=#{r["stty_restored"].inspect}"
  parts << "resize_events=#{r["resize_events"]}"
  if (s = r.dig("sim_stats", "steps", "posts"))
    parts << "posts_rate=#{s["achieved_rate"]}/#{s["planned_rate"]}"
  end
  if (f = r.dig("sim_stats", "forks"))
    parts << "forks=#{f["forked"]}/#{f["reaped"]}#{" ERR:#{f["fork_errors"]}" unless f["fork_errors"].to_a.empty?}"
  end
  parts.join(" ")
end

names = ARGV.empty? ? SCENARIOS.keys : ARGV
names.each do |name|
  spec = SCENARIOS.fetch(name)
  spec[:pipe] ? run_pipe_scenario(name, spec) : run_pty_scenario(name, spec)
end
