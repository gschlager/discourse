# frozen_string_literal: true

Migrations::CLI::Registry.register(
  name: "schema",
  command_class: "Migrations::Tooling::CLI::SchemaCommand",
  description: "Manage the IntermediateDB schema",
)

Migrations::CLI::Registry.register(
  name: "coverage",
  command_class: "Migrations::Tooling::CLI::CoverageCommand",
  description: "Analyse converter coverage of the IntermediateDB schema",
)

Migrations::CLI::Registry.register(
  name: "check",
  command_class: "Migrations::Tooling::CLI::CheckCommand",
  description: "Run all IntermediateDB schema and converter checks",
)
