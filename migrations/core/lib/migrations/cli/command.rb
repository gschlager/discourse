# frozen_string_literal: true

require "clamp"
require "clamp/completion"
require "colored2"
require "did_you_mean"

# Options may appear after positionals (`convert discourse --only x`), the way
# the previous Thor-based CLI allowed.
Clamp.allow_options_after_parameters = true

module Migrations
  module CLI
    # Base class for all `disco` commands. Commands that need a booted Rails
    # environment declare `requires_rails!`; Rails is booted only after such a
    # command has been selected and parsed, keeping help and Rails-free commands
    # fast.
    class Command < Clamp::Command
      # Coerces a comma-separated `--only`/`--skip` value into a list of
      # normalized step names. Shared by the `--only`/`--skip` option blocks.
      STEP_LIST = ->(value) do
        value.to_s.split(",").map { |name| name.strip.demodulize.underscore }
      end

      # Renders help with bold headings and a blue description. Clamp builds help
      # through a Builder; we subclass it to add the color.
      class HelpBuilder < Clamp::Help::Builder
        def add_usage(invocation_path, usage_descriptions)
          line "#{Clamp.message(:usage_heading)}:".bold
          usage_descriptions.each { |usage| line "    #{invocation_path} #{usage}".rstrip }
        end

        def add_description(description)
          return unless description

          line
          line description.gsub(/^/, "  ").blue
        end

        def add_list(heading, items)
          line
          line "#{heading}:".bold
          items
            .reject { |i| i.respond_to?(:hidden?) && i.hidden? }
            .each do |item|
              label, description = item.help
              description.each_line do |line_text|
                row(label, line_text)
                label = ""
              end
            end
        end
      end

      def self.requires_rails!
        @requires_rails = true
      end

      def self.requires_rails?
        return true if @requires_rails == true
        superclass.respond_to?(:requires_rails?) && superclass.requires_rails?
      end

      # Boot Rails only after a command is selected and parsed. `parse` raises for
      # `--help`, `--shell-completions`, or invalid input before we get here, so
      # those paths stay Rails-free.
      def run(arguments)
        parse(arguments)
        Migrations.load_rails_environment(quiet: true) if self.class.requires_rails?
        execute
      end

      # Use the colorized help builder.
      def self.help(invocation_path, builder = HelpBuilder.new)
        super
      end

      # Suggest the closest command when a sub-command is mistyped.
      def subcommand_missing(name)
        known = self.class.recognised_subcommands.flat_map(&:names)
        suggestions = DidYouMean::SpellChecker.new(dictionary: known).correct(name)
        message = +"Unknown command '#{name}'"
        message << "\nDid you mean: #{suggestions.join(", ")}?" if suggestions.any?
        signal_usage_error(message)
      end

      # Top-level entry point. Replaces Clamp's default `run` to colorize errors
      # and to generate shell-completion scripts. Other (presentable) errors are
      # handled one level up by {ExceptionHandler}.
      def self.run(invocation_path = BIN, arguments = ARGV, context = {})
        context[:root_command_class] ||= self
        new(invocation_path, context).run(arguments)
      rescue Clamp::UsageError => e
        warn e.message.red
        warn ""
        warn "See: '#{e.command.invocation_path} --help'"
        exit(1)
      rescue Clamp::HelpWanted => e
        puts e.command.help
      rescue Clamp::Completion::Wanted => e
        puts generate_completion(File.basename(e.shell).to_sym, invocation_path)
      rescue Clamp::ExecutionError => e
        warn e.message.red
        exit(e.status)
      end
    end
  end
end
