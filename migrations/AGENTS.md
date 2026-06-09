# Migrations Tooling — Agent Guide

Start with **[README.md](README.md)** — it is the single source of truth for this
project: gem layout and namespaces, the `disco` CLI, converters, the schema DSL,
and the install / test / lint workflow.

This file is reserved for **agent-specific** guidance that does not belong in the
README (conventions, gotchas, do/don't notes for automated contributors).

## Gotchas

The `disco` CLI is built on [Clamp](https://github.com/mdub/clamp). Commands
subclass `Migrations::CLI::Command` (a `Clamp::Command`) and implement `#execute`.
Each gem registers its top-level commands into `Migrations::CLI::Registry`, and
`Bootstrap` turns those into the Clamp sub-command tree just before parsing.

- **A command's body is `#execute`, never `#run`.** `Clamp::Command#run(arguments)`
  is the parse-then-dispatch entry point, and the base `Command` overrides it to boot
  Rails lazily. A helper that returns a value (e.g. the `check schema` / `check
  coverage` checks, which `check` also runs together) must be named something else —
  they use `#perform`. A no-arg `def run` shadows Clamp's dispatch and breaks the
  command.

- **Required positionals are native.** Use `parameter "TABLE_NAME", "…"`; Clamp
  enforces it and prints a clean usage error when it is missing. Optional ones use
  `parameter "[NAME]", "…"`. (There is no `require_positional!` — that was a samovar
  workaround.)

- **Options after positionals and `--opt=value` work out of the box.**
  `Clamp.allow_options_after_parameters = true` is set in `command.rb`, and Clamp
  parses `--opt=value` natively. Don't reimplement either.

- **Don't key an option `inspect`** (or any existing `Object` / `Clamp::Command`
  method name). Clamp derives an accessor from the option name, so `--inspect` would
  clobber `Object#inspect`. Pass `attribute_name:` instead — see `check coverage`'s
  `attribute_name: "inspected_converter"`.

- **Rails boot is opt-in and lazy.** Declare `requires_rails!` on commands that need a
  booted Rails environment; the base `Command#run` boots it after parsing so `--help`,
  shell completion, and Rails-free commands stay fast. `check` boots Rails itself for
  its no-subcommand "run everything" mode.

- **The shared `--db` option lives on `SchemaCommands::BaseCommand`**; schema
  sub-commands inherit it — don't redeclare it.

- **Colored help and shell completion are wired in `command.rb`** — help via a
  `Clamp::Help::Builder` subclass (bold headings, blue description), and `require
  "clamp/completion"` adds `--shell-completions` (bash/zsh/fish).
