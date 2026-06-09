# frozen_string_literal: true

RSpec.describe Migrations::Converters::CLI::ConvertCommand do
  subject(:command) { described_class.new("disco convert") }

  before { allow(Migrations::Converters).to receive(:names).and_return(%w[discourse vanilla]) }

  describe "#execute" do
    it "raises a presentable error listing valid converters when no type is given" do
      command.parse([])

      expect { command.execute }.to raise_error(
        described_class::Error,
        "Missing required argument: <converter_type>\nValid names are: discourse, vanilla",
      )
    end

    it "raises a presentable error for an unknown converter name" do
      command.parse(["bogus"])

      expect { command.execute }.to raise_error(
        described_class::Error,
        /Unknown converter name: bogus/,
      )
    end
  end
end
