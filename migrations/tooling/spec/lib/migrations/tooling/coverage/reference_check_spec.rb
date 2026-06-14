# frozen_string_literal: true

RSpec.describe Migrations::Tooling::Coverage::ReferenceCheck do
  subject(:check) { described_class.new }

  let(:schema_columns) { Migrations::Tooling::Coverage::SchemaColumns }
  let(:analyzer_class) { Migrations::Tooling::Coverage::ConverterAnalyzer }

  def model(name, required: [], optional: [])
    Migrations::Tooling::Coverage::SchemaColumns::Model.new(name:, required:, optional:)
  end

  def analysis(written: {}, unknown: {}, delegates_post_embeds: false)
    Migrations::Tooling::Coverage::ConverterAnalyzer::Result.new(
      written_columns: written.transform_values { |columns| Set.new(columns) },
      unknown_models: unknown,
      delegates_post_embeds:,
    )
  end

  # `results` maps converter name => analysis(...). The reference converter is
  # `discourse`, so include it unless a test is about its absence.
  #
  # `Migrations::Converters` lives in the converters gem, which isn't loaded in
  # the tooling gem's isolated specs, so a doubled constant stands in for it
  # (verified against the real module only where it happens to be loaded).
  def stub_coverage(results, schema:)
    converters = class_double("Migrations::Converters").as_stubbed_const
    allow(converters).to receive(:names).and_return(results.keys)
    allow(converters).to receive(:path_of) { |name| name }

    allow(analyzer_class).to receive(:new) do |path|
      instance_double(analyzer_class, analyze: results.fetch(path))
    end
    allow(schema_columns).to receive(:call).and_return(schema)
  end

  it "passes when the reference converter writes every column" do
    stub_coverage(
      { "discourse" => analysis(written: { "User" => %i[id name] }) },
      schema: {
        "User" => model("User", required: [:id], optional: [:name]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(/covers all/).to_stdout
    expect(passed).to be true
  end

  it "fails when the reference converter is missing a column" do
    stub_coverage(
      { "discourse" => analysis(written: { "User" => [:id] }) },
      schema: {
        "User" => model("User", required: [:id], optional: [:name]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(/does not write every/).to_stdout
    expect(passed).to be false
  end

  it "does not fail when a non-reference converter covers only a subset" do
    stub_coverage(
      {
        "discourse" => analysis(written: { "User" => %i[id name] }),
        "phpbb" => analysis(written: { "User" => [:id] }),
      },
      schema: {
        "User" => model("User", optional: %i[id name]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output.to_stdout
    expect(passed).to be true
  end

  it "fails when any converter writes a column the schema doesn't have" do
    stub_coverage(
      {
        "discourse" => analysis(written: { "User" => [:id] }),
        "phpbb" => analysis(written: { "User" => %i[id bogus] }),
      },
      schema: {
        "User" => model("User", optional: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(/columns that don't exist/).to_stdout
    expect(passed).to be false
  end

  it "fails when any converter writes to a model the schema doesn't have" do
    stub_coverage(
      {
        "discourse" => analysis(written: { "User" => [:id] }),
        "phpbb" => analysis(written: { "User" => [:id] }, unknown: { "Ghost" => ["steps/x.rb:1"] }),
      },
      schema: {
        "User" => model("User", optional: [:id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(/models that don't exist/).to_stdout
    expect(passed).to be false
  end

  it "credits the linkage tables when the reference converter delegates to PostEmbedWriter" do
    stub_coverage(
      { "discourse" => analysis(written: { "User" => %i[id name] }, delegates_post_embeds: true) },
      schema: {
        "User" => model("User", required: [:id], optional: [:name]),
        "PostUpload" =>
          model("PostUpload", required: %i[post_id placeholder], optional: [:upload_id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(/covers all/).to_stdout
    expect(passed).to be true
  end

  it "still reports linkage columns missing when the converter does not delegate" do
    stub_coverage(
      { "discourse" => analysis(written: { "User" => %i[id name] }, delegates_post_embeds: false) },
      schema: {
        "User" => model("User", required: [:id], optional: [:name]),
        "PostUpload" =>
          model("PostUpload", required: %i[post_id placeholder], optional: [:upload_id]),
      },
    )

    passed = nil
    expect { passed = check.run }.to output(/does not write every/).to_stdout
    expect(passed).to be false
  end

  it "raises when the reference converter is not among the discovered converters" do
    stub_coverage(
      { "phpbb" => analysis(written: { "User" => [:id] }) },
      schema: {
        "User" => model("User", optional: [:id]),
      },
    )

    expect { check.run }.to raise_error(described_class::Error, /discourse/)
  end
end
