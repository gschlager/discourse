# frozen_string_literal: true

module Migrations
  # The `disco` command-line interface.
  #
  # This is the explicit namespace file for `Migrations::CLI`: Zeitwerk loads it
  # whenever the namespace is first referenced, so constants defined here (e.g.
  # {BIN}) are available without forcing the CLI command stack to load — including
  # from non-CLI code such as the schema DSL.
  module CLI
    # How the binary is invoked from the repository root. Used in user-facing
    # messages, so that suggested commands are copy-pasteable.
    BIN = "migrations/bin/disco"
  end
end
