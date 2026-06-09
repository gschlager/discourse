# frozen_string_literal: true

RSpec.describe Migrations::CLI::Command do
  describe "STEP_LIST" do
    it "splits, strips, and normalizes comma-separated step names" do
      expect(described_class::STEP_LIST.call("Users, Posts")).to eq(%w[users posts])
      expect(described_class::STEP_LIST.call("Foo::BarStep")).to eq(%w[bar_step])
      expect(described_class::STEP_LIST.call("")).to eq([])
    end
  end

  describe ".requires_rails?" do
    it "defaults to false" do
      expect(Class.new(described_class).requires_rails?).to be(false)
    end

    it "is true once declared and is inherited by subclasses" do
      parent = Class.new(described_class) { requires_rails! }
      child = Class.new(parent)

      expect(parent.requires_rails?).to be(true)
      expect(child.requires_rails?).to be(true)
    end
  end

  # The behaviours that used to be hand-rolled (`hoist_options`,
  # `normalize_option_args`, `require_positional!`) are now provided by Clamp.
  describe "argument parsing" do
    let(:command_class) do
      Class.new(described_class) do
        self.description = "test command"
        option "--only", "STEPS", "Steps to run.", default: [] do |value|
          Migrations::CLI::Command::STEP_LIST.call(value)
        end
        parameter "TARGET", "The target."
        def execute
        end
      end
    end

    it "accepts the `--opt=value` form" do
      command = command_class.new("test")
      command.parse(%w[--only=a,b discourse])

      expect(command.only).to eq(%w[a b])
      expect(command.target).to eq("discourse")
    end

    it "accepts options after positionals" do
      command = command_class.new("test")
      command.parse(%w[discourse --only a,b])

      expect(command.target).to eq("discourse")
      expect(command.only).to eq(%w[a b])
    end

    it "raises a usage error when a required positional is missing" do
      command = command_class.new("test")

      expect { command.parse([]) }.to raise_error(Clamp::UsageError, /TARGET/)
    end
  end
end
