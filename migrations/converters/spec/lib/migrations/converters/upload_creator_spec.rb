# frozen_string_literal: true

RSpec.describe Migrations::Converters::UploadCreator do
  let(:upload_model) { Migrations::Database::IntermediateDB::Upload }

  describe "#create_for" do
    it "routes an external URL to Upload.create_for_url" do
      expect(upload_model).to receive(:create_for_url).with(
        url: "https://example.com/a.png",
        filename: "a.png",
        type: "avatar",
        origin: "https://forum.example.com/a.png",
        user_id: 5,
      )

      described_class.new(upload_type: "avatar").create_for(
        {
          url: "https://example.com/a.png",
          filename: "a.png",
          origin: "https://forum.example.com/a.png",
          user_id: 5,
        },
      )
    end

    it "prefixes a protocol-relative URL with https" do
      expect(upload_model).to receive(:create_for_url).with(
        hash_including(url: "https://cdn.example.com/a.png"),
      )

      described_class.new.create_for({ url: "//cdn.example.com/a.png", filename: "a.png" })
    end

    it "routes a local path to Upload.create_for_file" do
      expect(upload_model).to receive(:create_for_file).with(
        path: "/data/uploads/a.png",
        filename: "a.png",
        type: nil,
        origin: nil,
        user_id: nil,
      )

      described_class.new.create_for({ url: "/data/uploads/a.png", filename: "a.png" })
    end

    it "reads prefixed columns when a column_prefix is given" do
      expect(upload_model).to receive(:create_for_url).with(
        hash_including(url: "https://example.com/avatar.png", filename: "avatar.png", user_id: 7),
      )

      described_class.new(column_prefix: "avatar").create_for(
        {
          avatar_url: "https://example.com/avatar.png",
          avatar_filename: "avatar.png",
          avatar_user_id: 7,
        },
      )
    end

    it "does nothing when there is no url or path" do
      expect(upload_model).not_to receive(:create_for_url)
      expect(upload_model).not_to receive(:create_for_file)

      expect(described_class.new.create_for({})).to be_nil
    end
  end

  it "is reachable as a bare `UploadCreator` from a Discourse step after the move" do
    # The Discourse steps reference `UploadCreator` unqualified; lexically nested
    # under `Migrations::Converters`, that still resolves here after de-namespacing.
    processor = Migrations::Converters::Discourse::Users.processor_class.new
    processor.setup

    expect(processor.instance_variable_get(:@avatar_upload_creator)).to be_a(described_class)
    expect(Migrations::Converters::Discourse.const_defined?(:UploadCreator, false)).to be(false)
  end
end
