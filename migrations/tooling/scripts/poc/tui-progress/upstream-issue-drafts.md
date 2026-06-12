# Draft issues for marcoroth/bubbletea-ruby

Checked 2026-06-13: no existing issue or PR covers either topic (open issues are #9
Fiber scheduler support and #8 Intel macOS crash). Drafts below; numbers come from
this POC (`out/*.report.json`), measured with bubbletea 0.1.4 / Ruby 3.4.9 on Linux.

---

## Issue 1: poll_event blocks the whole Ruby VM (GVL is never released)

`Program#poll_event` calls `tea_input_read_raw`, which blocks in a Go channel
`select` for up to `timeout_ms`, directly from the C extension without
`rb_thread_call_without_gvl`. Since `Runner#run_loop` calls `poll_event(10)` every
iteration, a running Bubbletea program holds the GVL almost continuously, and every
other Ruby thread in the process starves.

Reproduction: a background thread that tries to do work every 5 ms (200 iterations/s)
managed only ~9 iterations/s while a Bubbletea program was running. Replacing the run
loop with one that polls with a 1 ms timeout once per frame and spends the rest of the
frame in Ruby `sleep` brought the same thread to ~147 iterations/s, so the cause is
clearly the GVL being held inside `poll_event`.

Suggested fix: wrap the `tea_input_read_raw` call in `program_poll_event` (and
`program_read_raw_input`) in `rb_thread_call_without_gvl`, so the wait happens with
the GVL released. Happy to test a patch.

## Issue 2 (feature request): external message posting and println

Two Go-bubbletea facilities that matter for programs whose state is produced by
background threads (progress UIs etc.):

1. **`Program.Send` equivalent.** `Runner#send` exists and works from other threads,
   but `Bubbletea.run` never exposes the runner instance, and the pending-messages
   array is built/swapped without synchronization. Exposing the runner (return it, or
   yield it) plus a `Thread::Queue` for pending messages would make this a supported
   path.

2. **`tea.Println` equivalent.** The renderer (`renderer.go`) has no queued-message
   support; `Bubbletea.puts` writes to stderr with `\r` and corrupts the inline
   renderer's region (lines get duplicated/overwritten). Upstream bubbletea inserts
   queued lines above the live region inside the renderer so they scroll into
   terminal history. Without this, long-running programs can't emit persistent log
   lines while rendering.
