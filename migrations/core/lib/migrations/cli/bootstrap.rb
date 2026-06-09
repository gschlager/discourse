# frozen_string_literal: true

require "clamp"

module Migrations
  module CLI
    # Builds the Clamp command tree from the registry and dispatches. Rails is
    # booted lazily by each command (see {Command#run}), so help and Rails-free
    # commands stay fast. `--opt=value`, options-after-positionals, required
    # positionals, did-you-mean, and per-command `--help` are all handled by
    # Clamp / the base {Command}.
    module Bootstrap
      def self.run(argv)
        build_root_command.run(BIN, argv)
      end

      # Each gem requires its `register.rb` at startup, which pushes its commands
      # into the {Registry}. We turn those into Clamp sub-commands here, just
      # before argv is parsed.
      def self.build_root_command
        entries = Registry.entries_sorted

        Class.new(Command) do
          self.description = "Discourse migration tools"
          entries.each do |name, description, command_class|
            subcommand(name, description.to_s, command_class)
          end
        end
      end
    end
  end
end
