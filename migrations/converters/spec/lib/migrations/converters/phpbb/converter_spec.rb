# frozen_string_literal: true

RSpec.describe Migrations::Converters::Phpbb::Converter do
  it "is a conversion base the framework can run" do
    expect(described_class.ancestors).to include(Migrations::Conversion::Base)
  end

  it "loads every step as a discoverable ProgressStep" do
    step_names = %i[
      Users
      AnonymousUsers
      Groups
      GroupMembers
      Categories
      Topics
      Posts
      Messages
      Permalinks
      Polls
      PollOptions
      PollVotes
    ]

    step_names.each do |name|
      klass = Migrations::Converters::Phpbb.const_get(name)
      expect(klass.ancestors).to include(Migrations::Conversion::ProgressStep),
      "expected Phpbb::#{name} to be a ProgressStep"
    end
  end

  it "loads the source and content collaborators (not as steps)" do
    %i[Source Capabilities Content LegacyCleaner].each do |name|
      klass = Migrations::Converters::Phpbb.const_get(name)
      expect(klass).to be_a(Class)
      expect(klass.ancestors).not_to include(Migrations::Conversion::StepBase)
    end
  end
end
