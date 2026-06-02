# Migrations Tooling — Agent Guide

Start with **[README.md](README.md)** — it is the single source of truth for this
project: gem layout and namespaces, the `disco` CLI, converters, the schema DSL,
and the install / test / lint workflow.

This file is reserved for **agent-specific** guidance that does not belong in the
README (conventions, gotchas, do/don't notes for automated contributors).

## Gotchas

- **Samovar reserves `name` on commands.** `Nested#parse` instantiates a
  sub-command with `name:` (its invocation name), which Samovar stores and exposes
  as `name`. So don't declare a positional `one :name` on a `disco` command — when
  the argument is omitted the accessor silently reads back the command's own name
  (e.g. `"convert"`) instead of `nil`. Name the positional something else
  (`one :converter, …`).
