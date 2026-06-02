# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Coverage::ConverterAnalyzer do
  describe "#written_columns" do
    around do |example|
      Dir.mktmpdir do |dir|
        @converter_path = dir
        example.run
      end
    end

    def write_source(relative_path, source)
      path = File.join(@converter_path, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, source)
    end

    it "unions columns for a model written across multiple files" do
      write_source("steps/users.rb", "IntermediateDB::User.create(username: 'a')")
      write_source("steps/more_users.rb", "IntermediateDB::User.create(name: 'n', trust_level: 1)")

      result = described_class.new(@converter_path).written_columns

      expect(result["User"]).to contain_exactly(:username, :name, :trust_level)
    end

    it "collects columns per model across the whole converter tree" do
      write_source("steps/users.rb", "IntermediateDB::User.create(username: 'a')")
      write_source("helpers/badges.rb", "IntermediateDB::Badge.create(name: 'b', original_id: 1)")

      result = described_class.new(@converter_path).written_columns

      expect(result.keys).to contain_exactly("User", "Badge")
    end

    it "returns an empty result when no .create calls are present" do
      write_source("steps/noop.rb", "puts 'nothing here'")

      expect(described_class.new(@converter_path).written_columns).to be_empty
    end

    it "fails loudly when any source contains an unverifiable call site" do
      write_source("steps/users.rb", "IntermediateDB::User.create(**attributes)")

      expect { described_class.new(@converter_path).written_columns }.to raise_error(
        Migrations::Tooling::Coverage::AnalysisError,
      )
    end
  end
end
