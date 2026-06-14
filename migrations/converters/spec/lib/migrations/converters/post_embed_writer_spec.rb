# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Converters::PostEmbedWriter do
  let(:placeholder) { Migrations::Placeholder.new(nonce: "n") }
  let(:buffer) { Migrations::Converters::EmbedBuffer.new(placeholder:) }

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @intermediate_db = Migrations::Database.connect(db_path)
      Migrations::Database::IntermediateDB.setup(@intermediate_db)
      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
    end
  end

  def rows(table)
    [].tap do |result|
      @intermediate_db.query("SELECT * FROM #{table} ORDER BY rowid") { |row| result << row }
    end
  end

  it "drains every kind of descriptor into its linkage table, splatting cleanly" do
    upload = buffer.upload(upload_id: "abc123")
    quote = buffer.quote(quoted_post_id: 200, quoted_user_id: 5, quoted_username: "bob")
    mention = buffer.mention(mention_type: "user", target_id: 7, name: "carol")
    link =
      buffer.link(url: "https://example.com", text: "here", target_topic_id: 9, target_post_id: 10)
    poll = buffer.poll(poll_id: 3)
    event = buffer.event(event_id: 4)

    described_class.write(100, buffer)

    expect(rows("post_uploads")).to contain_exactly(
      { post_id: 100, placeholder: upload, upload_id: "abc123" },
    )
    expect(rows("post_quotes")).to contain_exactly(
      {
        post_id: 100,
        placeholder: quote,
        quoted_post_id: 200,
        quoted_user_id: 5,
        quoted_username: "bob",
      },
    )
    expect(rows("post_mentions")).to contain_exactly(
      { post_id: 100, placeholder: mention, mention_type: "user", target_id: 7, name: "carol" },
    )
    expect(rows("post_links")).to contain_exactly(
      {
        post_id: 100,
        placeholder: link,
        url: "https://example.com",
        text: "here",
        target_topic_id: 9,
        target_post_id: 10,
      },
    )
    expect(rows("post_polls")).to contain_exactly({ post_id: 100, placeholder: poll, poll_id: 3 })
    expect(rows("post_events")).to contain_exactly(
      { post_id: 100, placeholder: event, event_id: 4 },
    )
  end

  it "writes nothing for an empty buffer" do
    described_class.write(100, buffer)

    expect(rows("post_uploads")).to be_empty
    expect(rows("post_quotes")).to be_empty
    expect(rows("post_mentions")).to be_empty
    expect(rows("post_links")).to be_empty
    expect(rows("post_polls")).to be_empty
    expect(rows("post_events")).to be_empty
  end

  it "writes one linkage row per buffered embed of the same kind" do
    first = buffer.upload(upload_id: "one")
    second = buffer.upload(upload_id: "two")

    described_class.write(100, buffer)

    expect(rows("post_uploads")).to contain_exactly(
      { post_id: 100, placeholder: first, upload_id: "one" },
      { post_id: 100, placeholder: second, upload_id: "two" },
    )
  end
end
