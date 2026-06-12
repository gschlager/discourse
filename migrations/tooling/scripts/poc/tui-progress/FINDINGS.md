# charm-ruby multi-progressbar POC — findings

Feasibility gate for rendering the converter's multi-step progress display with the
charm-ruby stack ([bubbletea](https://github.com/marcoroth/bubbletea-ruby) 0.1.4,
[bubbles](https://github.com/marcoroth/bubbles-ruby) 0.1.1,
[lipgloss](https://github.com/marcoroth/lipgloss-ruby) 0.2.2, harmonica 0.1.1 as a
bubbles dependency) on Ruby 3.4.9 (+YJIT). Everything below was measured with the
scripts in this directory, run under a PTY harness (`pty_driver.rb`); reconstructed
screens, JSON reports, and tmux/screen captures are in `out/` (the raw byte captures
are not committed — re-run the driver to regenerate them).

## Recommendation: use the ANSI fallback

bubbletea-ruby is *technically* "viable with workarounds" — every checklist item can be
made to work — but two of the workarounds replace the framework's core (its event loop
and its output model), and the one requirement it cannot meet cleanly is one the
converter actually cares about: notice/finished lines must persist in terminal history
on runs whose output exceeds the screen. The hand-rolled ANSI renderer
(`poc_ansi.rb`, ~250 lines, stdlib only) meets every requirement, beats bubbletea on
every measurement, and removes ~42 MB of Go-binary platform gems from the dependency
question. Details per checklist item below; comparison numbers at the end.

Architecture note that explains most findings: bubbletea-ruby is not a Ruby event loop
over a Go renderer goroutine — the Elm loop (`Bubbletea::Runner#run_loop`) is plain
Ruby; the Go side (a static library compiled into the C extension) provides raw mode,
an input-reader goroutine, ANSI string width, and a full-repaint renderer that skips
identical frames. There is no Go `Program`/`tea.Println`/message bus behind it.

## Capability checklist

### 1. Install — PASS (with a deployment caveat)

`gem install bubbletea bubbles lipgloss` resolves and loads on Ruby 3.4.9. bubbletea
and lipgloss ship as prebuilt platform gems (Go static lib inside a C extension;
2.8 MB / 3.4 MB `.so`, 19 MB / 23 MB unpacked per platform); bubbles and harmonica are
pure Ruby. The C extension never releases the GVL (zero `rb_thread_call_without_gvl`
in the extension — see item 2). Source builds need Go 1.23+, relevant for platforms
without a prebuilt gem.

### 2. External message posting — WORKAROUND REQUIRED (the deciding item)

There is no `Program.Send` equivalent in the public API surface (`Bubbletea.run`
doesn't even expose the runner). `Runner#send(message)` exists, is thread-safe enough
in practice (unsynchronized array append/swap; 0 messages lost across ~1,400 per run
in all full runs), and works from plain threads — but only usefully after replacing
the run loop:

- **Stock loop**: each iteration blocks in `poll_event(10 ms)` *holding the GVL*
  (cgo channel-select, no GVL release). The TUI thread starves every producer: the
  200 updates/sec producer achieved **9.1 updates/sec** (`stock_full` report). In the
  real converter this would throttle the conversion itself. Disqualifying as shipped.
- **Paced loop workaround** (`PacedRunner`, ~20 lines): poll input 1 ms per frame,
  spend the rest of the frame in Ruby `sleep` (GVL released). Producer reaches
  147/200 updates/sec, message latency 12 ms avg / 37 ms max, zero >100 ms. Works, but
  overrides a private method and touches `@running`/`@program` internals — version-pinned
  monkey-patching of a 0.1.x gem.

### 3. Multiple progress bars — PASS

`Bubbles::Progress` is pure Ruby with a static `view_as(percent)` mode (the spring
animation is optional). 3–4 concurrent bars plus a spinner rendered without flicker or
interleaving: every frame in the captures is a complete, well-formed repaint (single
buffered write per frame), `paced_ctrlc.screen.txt` shows the mid-run state cleanly.

### 4. Output above the live region — FAIL (workaround exists but lossy)

The make-or-break gap. The Go renderer has no `tea.Println`/queued-message support;
`Bubbletea.puts` is literally `warn "\r#{text}\r"` and corrupts the display (the
`puts_mode` capture shows six duplicated `✓ Categories` lines, an orphaned stale bar,
and most notices overwritten). The workaround — put notices + finished lines at the
top of the growing view — renders correctly **until the view exceeds terminal
height**: the renderer then clips to the *last* `height` lines, so older permanent
lines vanish from display and never land in scrollback (`small_height` capture: the
first 4 history lines are gone at 10 rows). A long converter run with accumulating
notices loses its history. Bounding the in-view history is possible but gives up the
"persist" requirement.

### 5. Render-loop performance — PASS

Coalescing works: ~1,400 posted updates produced 191 terminal writes in a ~12 s run
(frame-rate bound at 30 fps; identical frames skipped Go-side). Process CPU during the
active phase ~26–30% of one core (includes all six producer threads and per-event JSON
parsing in `poll_event`); idle tail 6.6–7.3% (the 1 ms poll + 30 fps view rebuild).

### 6. No-input operation — PASS (with a signal-semantics caveat)

Runs fine with no keyboard input. But raw mode means Ctrl-C arrives as a `ctrl+c`
*key event*, not SIGINT — the model must translate it (quit + re-raise `Interrupt`)
for the converter's `SignalException` path; the POC does this and exits 130 with the
terminal restored. A real `SIGINT` (kill) is *not* swallowed by the embedded Go
runtime: Ruby's handler raises `Interrupt` in the main thread, the runner's `ensure`
restores the terminal (`paced_sigint`: exit 130, cursor restored, `stty -g`
before/after identical).

### 7. Terminal lifecycle — PASS

Normal exit, Ctrl-C key, and SIGINT all restore the terminal: `stty -g` identical
before/after, `\e[?25h` (show cursor) present in the output tail, post-exit text
prints on a clean new line in every capture.

### 8. Fork safety — PASS

4 children forked mid-animation (from a non-main thread, reaped with `Process.wait2`
from that thread), all exited 0, across every full run. No render stall (latency max
stayed ~37 ms through the fork window), no terminal corruption, no SIGCHLD interference
from the Go runtime's signal handlers. Children inherit the raw-mode terminal — they
must not touch stdout/stderr or run cleanup (`exit!`), which matches how ForkManager
workers behave (IPC via pipes).

### 9. Non-TTY behavior — DEGRADES SILENTLY (detectable upstream only)

`script | cat </dev/null`: no crash, no hang — `MakeRaw` fails silently, the renderer
happily writes 110 KB of ANSI into the pipe, exit 0. Fine per the brief (reporter
selection happens upstream via `$stdout.tty?`), but the gem itself gives no error to
detect.

### 10. Cosmetics — PASS

lipgloss colors render under the PTY (named ANSI + 24-bit sequences; auto-stripped
when stdout is not a tty). Width handling matches expectations: `✓`/`⚠`/`✗` = 1 cell,
`🚀` = 2, `"Likes 🚀"` = 8 — emoji step titles align correctly in all captures. Resize
(110→60→110 cols mid-run) is handled via the runner's WINCH trap with clean repaints;
on a 34-col terminal lines are truncated ANSI-aware by the renderer with no wrap
garbling.

## The ANSI fallback POC (`poc_ansi.rb`)

Same simulation harness (`sim_harness.rb`), zero gems (stdlib `io/console` + `reline`
for character width). Cursor-up + line-rewrite live region; permanent lines are
emitted at the top of the region each frame and scroll into real terminal history.
Cooked mode throughout — no raw mode, no input reader.

- **Persistence**: at 10 rows, the *entire* history survives in scrollback with final
  content (`ansi_small_height.screen.txt`) — the requirement bubbletea can't meet.
- **Signals**: Ctrl-C through the pty line discipline is a real SIGINT; the converter's
  `SignalException` path needs no translation. Exit 130, terminal restored. The only
  artifact is the terminal's own `^C` echo (cosmetic; `stty -echoctl` if we care).
- **Performance**: producer reached 195/200 updates/sec; latency 16 ms avg / 33 ms max,
  zero >100 ms; CPU 2.7% active / ~0% idle — an order of magnitude below bubbletea
  (no cgo polling, no per-event JSON, frame-skip when nothing changed).
- **Non-TTY**: detects `!$stdout.tty?` and exits 2 with a clear message.
- **Forks, resize, narrow terminals**: same scenarios as bubbletea, all clean.
- One real-implementation note: use the `unicode-display_width` gem instead of Reline
  for widths. Reline probes ambiguous-width characters by writing `\e[6n` to the
  terminal and waiting (~500 ms one-time stall if nothing answers, and it reads the
  reply from stdin). The PTY driver answers the probe like a real terminal; with that,
  zero latency spikes.
- Known bounds, both fine for the converter: the live region must fit the terminal
  height (concurrent steps are scheduler-bounded); permanent lines are frozen at the
  width they were emitted at (no reflow after resize).

## tty-progressbar, tested as a third option (`poc_tty.rb`)

TTY::ProgressBar::Multi 0.18.3 (pure Ruby; deps tty-cursor, tty-screen,
strings-ansi, unicode-display_width) on the same harness. The mechanics are fine:
Monitor-synchronized `advance` straight from producer threads (0.25 ms avg / 22 ms max
per call), `frequency:` throttling keeps output frame-bound, 188–190/200 producer
rate, ~4% CPU, native SIGINT (no raw mode), renders nothing when stdout is not a tty,
forks clean. What disqualifies it is the display model:

- **`log` does not persist above a multi-bar region.** The raw capture shows the
  protocol: `\e7` save, `\e[1A` up one row, message *over an existing bar row*,
  `\r\n`, `\e8` restore — no line insertion, no region re-render. The next bar redraw
  overwrites the message; only notices logged after rendering quiets down survive
  (`tty_full.raw` / `.screen.txt`).
- Finished bars stay as full-width 100% rows in registration order — no collapsing to
  compact `✓` lines, no completion-order history, and the region grows monotonically
  with one row per step ever started.
- Rewrites carry no erase-to-EOL, so shrinking content leaves residue; annotations and
  colors are ours to build via format tokens anyway.

So the hard 10% — a persistent, collapsing history above a live multi-bar region — is
still hand-rolled on top of it, while the layout gets *more* constrained than with the
ANSI fallback. Not worth the trade.

## Why hand-rolling isn't as big as the gems suggest

The gems' size buys generality, not the rendering protocol. Where their LOC goes:

- tty-progressbar, 2,082 LOC: ~620 in the bar state machine + public API, ~430 in the
  format-token DSL/pipeline (`:bar :eta :rate :byte_rate …`), 156 in configuration
  options, 120 in a gallery of predefined formats, 116 in rate/ETA math, 283 in Multi.
- ruby-progressbar, 1,297 LOC: same shape (components, smoothing projectors, format
  DSL) with no multi-bar at all.
- bubbletea-ruby, 2,367 LOC (Go+C+Ruby): roughly half is input — key/mouse/focus
  parsing, raw mode, alt screen — which a no-input progress display doesn't use; the
  inline renderer core is ~100 lines of Go.

Our renderer has one fixed layout, one consumer, and no public API, so that work
doesn't shrink — it disappears. The genuinely hard sub-problems are delegated or out
of scope: Unicode width is `unicode-display_width` (the part nobody should hand-roll),
ETA smoothing is three lines of EMA math (see the parity section below — proven in the
POC with ExtendedProgressBar's exact parameters), and there is no keyboard handling.
What remains is the live-region protocol — 43 lines (`AnsiRenderer#repaint`) of a
well-trodden pattern (Docker/BuildKit and cargo hand-roll the same thing instead of
using a library). The POC's working core is ~190 lines; expect 2–3× with polish and
tests, still an order of magnitude below the gems.

## Feature parity with today's `ExtendedProgressBar`

The current UX (`migrations/core/lib/migrations/common/extended_progress_bar.rb` on
ruby-progressbar, used by the importer and `ProgressStepExecutor`) sets the baseline —
the TUI must not regress it. Feature by feature:

- **Smoothed ETA** (`%E` with `projector: {type: "smoothing", strength: 0.5}`):
  ruby-progressbar's `SmoothedAverage` is an exponential moving average —
  `projection = new*(1-strength) + projection*strength` — wrapped in ~70 lines of
  projector API. The POC now computes the same EMA (strength 0.5) per progress event
  and renders `ETA m:ss` per running step; measurements unchanged (15.8 ms avg
  latency, 2.7% CPU). ruby-progressbar stays a migrations-core dependency anyway, so
  the real implementation can even reuse `ProgressBar::Projectors::SmoothedAverage`
  as a plain object instead of inlining the math.
- **Skip/warning/error counts** (I18n-pluralized, colored2-colored, shown only when
  > 0): the POC renders warnings/errors with the same conditional logic; skips are a
  third counter of identical shape, and the real renderer should use the existing
  `progressbar.*` locale keys. The reporter interface must carry `skip_count` —
  the importer uses it even though the converter path currently doesn't.
- **Different format before/while/after** (`calculate_format` → run → `finalize`
  which drops the ETA and prints `\033[K` to clear residue): structurally the same as
  the POC's running-line → collapsed-✓-line transition. The `\033[K` workaround exists
  because ruby-progressbar leaves residue when a line shortens — the POC's renderer
  writes erase-to-EOL on every line, which removes that bug class wholesale.
- **Update throttling** (`throttle_rate: 0.5`, i.e. at most 2 redraws/s): needed there
  because ruby-progressbar renders synchronously inside `update`/`increment` on the
  caller's thread. The POC's frame loop is the same mechanism generalized — producers
  never render, the render thread samples at fps and skips identical frames, and the
  final state is force-rendered on finish (`repaint(final: true)`, the equivalent of
  `finish`'s forced update). Display churn is bounded by quantizing elapsed/ETA to
  whole seconds, not by dropping updates.

One open design choice surfaced by the interrupt scenario: today the POC erases
still-running lines on Ctrl-C (only finished steps persist); ExtendedProgressBar
leaves whatever was on screen. The real TUI should probably collapse running steps to
an "interrupted at N%" line instead — trivial either way, but worth deciding in the
PR.

## Terminal environment matrix

The selection ladder (implemented in `poc_ansi.rb`): full TUI only when stdout is a
tty AND `TERM` is neither empty nor `dumb`; otherwise plain line output — one line per
step start/finish plus one per progress decile, notices as-is, no cursor codes
(`PlainRenderer`, ~45 lines). Tested:

| environment | result |
|---|---|
| tmux 3.6b, 110×32 and 110×10 | TUI path; `capture-pane` (real emulator state, not our interpreter) shows clean rendering, full history in tmux scrollback even at 10 rows |
| GNU screen 5.0.1 | TUI path; clean rendering and history; screen's hardcopy shows 🚀 as `？` (screen quirk — argues for no emoji in real step titles) |
| pipe / CI (GitHub Actions shape) | plain mode via `tty?` → readable decile log, exit 0 (`ansi_pipe`) |
| `TERM=dumb` on a real pty | plain mode (`ansi_dumb`) |
| tmux window resized mid-run | grow: fully clean; shrink with a multi-line region: at most fragments of the topmost live lines survive (see below) |
| RubyMine run console | default console is a non-tty pipe → plain mode — the same mechanism that makes ExtendedProgressBar degrade there today (ruby-progressbar auto-selects `Outputs::NonTty` on `tty?` false); with "Emulate terminal in output console" it is a pty with a real TERM → TUI path. Not testable in this environment; both branches of the ladder cover it. |
| SSH | transparent byte stream; rendering happens in the user's local terminal and TERM comes from the client — nothing to detect server-side |

### Resize on reflowing terminals

Shrinking the window is the one case a PTY-level test can't judge: emulators that
reflow (tmux, VTE, iTerm2, kitty) rewrap already-drawn rows *at the instant of
resize, before WINCH reaches the process*, so the live region's physical height
becomes unknown and cursor-up arithmetic anchors wrong. This is inherent to every
inline renderer (Go bubbletea inline mode and tty-progressbar included); only
alt-screen TUIs avoid it, at the cost of the scrollback persistence we require.
Resizing tmux mid-run initially produced a real artifact: tmux wrapped a live row at
shrink, kept the wrap flag while we overwrote those rows, and rejoined them on grow —
merging two of our lines into one. Two renderer changes fix it (verified in tmux,
shrink 110→60 and back mid-run, clean final screen and history):

1. **Bounded reclaim on WINCH** — the old region is at least `live_count` physical
   rows tall whatever the emulator did (rewrapping never shrinks it), so cursor-up
   `live_count - 1` is provably still within our own rows. Move there, erase to end
   of screen, repaint. Pure grows and non-reflowing terminals lose the entire stale
   region; reflowing shrinks lose everything below the landing row.
2. **Erase-entire-line before writing** (`\e[2K` + content instead of content +
   erase-tail) — clears the emulator's wrap flags on rewritten rows, so grow no
   longer rejoins them.

Verified in tmux: a mid-run grow (60→110) leaves zero artifacts; a mid-run shrink
(110→60 with 3 live bars) leaves a single truncated fragment of the topmost live
line in history. That fragment is the floor for inline renderers — removing it would
need a DSR cursor-position probe (reading stdin in cbreak mode), not worth it here.
Wrap-flag behavior varies by emulator, so eyeball per terminal; the reclaim bound
itself is emulator-agnostic.

Note: the current migrations tree has no tty/TERM/RubyMine detection of its own —
today's graceful degradation comes entirely from ruby-progressbar's Tty/NonTty output
split. The plain mode above is the TUI-era replacement for that, and doubles as the
CI-readable output format.

Two findings from this POC make the case sharper. First, gem maturity didn't buy
correctness in our corner: all three libraries, after years of development, are broken
or absent exactly at "persistent log lines above a live multi-bar region" — adopting
one means writing the hard part anyway, on top of rendering behavior we don't control.
Second, the risk is testable and reversible: the PTY driver + screen emulator catch
rendering artifacts mechanically (they caught bubbletea's `puts` corruption, tty's
`log` overwrite, and a Reline `\e[6n` stall), the scenario matrix becomes the
regression suite, and the renderer sits behind the same sink interface that drove
three different backends in this POC — swapping later is a ~150-line adapter, not a
rewrite. Known scope decisions to make explicit in the PR: ANSI terminals only
(modern Windows Terminal included, legacy console API not), and notices may contain
user data, so width handling must go through `unicode-display_width` everywhere.

## Measurements side by side

Full simulation (~12 s, 6 steps, ~1,400 updates incl. a 200/s producer, 4 mid-run
forks), 110×32 PTY, 30 fps. From `out/*.report.json`.

| | bubbletea stock loop | bubbletea paced loop | tty-progressbar Multi | ANSI fallback |
|---|---|---|---|---|
| 200/s producer achieved | **9.1/s** | 147/s | 189/s | 196/s |
| update latency avg / max | 8 / 26 ms | 12 / 37 ms | n/a (sync render, 0.25/22 ms per call) | 16 / 33 ms |
| process CPU active / idle | 29% / 11% | 26% / 7% | 4% / 0% | **2.7% / 0.3%** |
| terminal writes per run | 91 | 191 | ~300 | 194 |
| messages lost | 0 | 0 | 0 | 0 |
| notice/finished history | lost beyond screen height | lost beyond screen height | overwritten by bar redraws | **persists** |
| finished steps collapse to ✓ lines | yes (in view) | yes (in view) | no — bars stay as rows | yes |
| Ctrl-C → SignalException | needs translation | needs translation | native | native |
| extra dependencies | 2 Go platform gems + 2 Ruby gems | same | 5 small pure-Ruby gems | none |

## Reproducing

```
ruby pty_driver.rb                  # all scenarios (bubbletea + ansi + tty + pipes)
ruby pty_driver.rb paced_full       # one scenario
ruby poc_bubbletea.rb               # interactive, in a real terminal
ruby poc_ansi.rb                    # interactive, in a real terminal
ruby poc_tty.rb                     # interactive, in a real terminal
```

Per scenario, `out/` gets the raw byte capture (`.raw`), a reconstructed final screen
(`.screen.txt`, via the line-based ANSI interpreter in the driver), and the POC's
self-reported metrics (`.report.json`).

## Outcome wiring (from the brief)

The TUI reporter brief's "Library feasibility gate" is settled: start from the ANSI
fallback. The brief's renderer sections apply with the same interface and layout,
hand-rolled rendering per `poc_ansi.rb`; `sim_harness.rb` is the seed for the TUI's
manual test script. `AnsiRenderer#repaint` + the event-queue drain is the shape of the
future `ConsoleReporter`/TUI renderer internals.
