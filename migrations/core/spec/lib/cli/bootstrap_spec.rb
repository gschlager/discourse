# frozen_string_literal: true

RSpec.describe Migrations::CLI::Bootstrap do
  describe ".build_root_command" do
    let(:dummy_command) do
      Class.new(Migrations::CLI::Command) do
        self.description = "Dummy command"
        def execute
        end
      end
    end

    before { Migrations::CLI::Registry.reset! }
    after { Migrations::CLI::Registry.reset! }

    it "registers each registry entry as a Clamp sub-command" do
      Migrations::CLI::Registry.register(
        name: "dummy",
        command_class: dummy_command,
        description: "Dummy command",
      )

      root = described_class.build_root_command

      expect(root.recognised_subcommands.flat_map(&:names)).to eq(["dummy"])
      expect(root.find_subcommand("dummy").subcommand_class).to eq(dummy_command)
      expect(root.find_subcommand("dummy").description).to eq("Dummy command")
    end

    it "orders sub-commands by registration name" do
      Migrations::CLI::Registry.register(name: "zebra", command_class: dummy_command)
      Migrations::CLI::Registry.register(name: "alpha", command_class: dummy_command)

      root = described_class.build_root_command

      expect(root.recognised_subcommands.flat_map(&:names)).to eq(%w[alpha zebra])
    end
  end
end
