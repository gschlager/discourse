# frozen_string_literal: true

RSpec.describe Migrations::Converters::Phpbb::Dialect do
  describe ".for" do
    it "returns the MySQL dialect" do
      expect(described_class.for(:mysql)).to be_a(described_class::MySQL)
    end

    it "returns the Postgres dialect" do
      expect(described_class.for(:postgres)).to be_a(described_class::Postgres)
    end

    it "accepts a string type" do
      expect(described_class.for("mysql")).to be_a(described_class::MySQL)
    end

    it "raises on an unknown dialect" do
      expect { described_class.for(:sqlite) }.to raise_error(
        described_class::UnknownDialect,
        /sqlite/,
      )
    end
  end

  describe described_class::MySQL do
    subject(:dialect) { described_class.new }

    it { expect(dialect.epoch_now).to eq("UNIX_TIMESTAMP()") }

    it "builds a JSON array aggregate" do
      expect(dialect.json_array_agg("x")).to eq("JSON_ARRAYAGG(x)")
    end

    it "builds a JSON object" do
      expect(dialect.json_object("'a', b")).to eq("JSON_OBJECT('a', b)")
    end

    it "aggregates distinct ids into a fake-JSON string" do
      expect(dialect.id_array_agg("pt.user_id")).to eq(
        "CONCAT('[', GROUP_CONCAT(DISTINCT pt.user_id), ']')",
      )
    end

    it "quotes identifiers with backticks and escapes them" do
      expect(dialect.quote_identifier("phpbb_users")).to eq("`phpbb_users`")
      expect(dialect.quote_identifier("a`b")).to eq("`a``b`")
    end
  end

  describe described_class::Postgres do
    subject(:dialect) { described_class.new }

    it { expect(dialect.epoch_now).to eq("EXTRACT(EPOCH FROM NOW())::bigint") }

    it "builds a JSON array aggregate" do
      expect(dialect.json_array_agg("x")).to eq("json_agg(x)")
    end

    it "builds a JSON object" do
      expect(dialect.json_object("'a', b")).to eq("jsonb_build_object('a', b)")
    end

    it "aggregates distinct ids into a real JSON array" do
      expect(dialect.id_array_agg("pt.user_id")).to eq("json_agg(DISTINCT pt.user_id)")
    end

    it "quotes identifiers with double quotes and escapes them" do
      expect(dialect.quote_identifier("phpbb_users")).to eq('"phpbb_users"')
      expect(dialect.quote_identifier('a"b')).to eq('"a""b"')
    end
  end

  it "diverges on exactly the fragments the phpBB queries need" do
    mysql = described_class::MySQL.new
    postgres = described_class::Postgres.new

    expect(mysql.epoch_now).not_to eq(postgres.epoch_now)
    expect(mysql.id_array_agg("x")).not_to eq(postgres.id_array_agg("x"))
    expect(mysql.json_object("a, b")).not_to eq(postgres.json_object("a, b"))
  end
end
