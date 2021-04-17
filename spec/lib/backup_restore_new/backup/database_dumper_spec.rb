# frozen_string_literal: true

require 'rails_helper'

describe BackupRestoreNew::Backup::DatabaseDumper do
  let(:io) { StringIO.new }

  describe "#dump_public_schema" do
    it "raises an exception when the last output of pg_dump is an error" do
      dumper = described_class.new(schema: "non_existent_schema")
      expect { dumper.dump_schema(io) }.to raise_error(BackupRestoreNew::Backup::DatabaseBackupError)
    end

    it "dumps the public schema by default" do
      status = mock("pg_dump status")
      status.expects(:exitstatus).returns(0).once
      Process.expects(:last_status).returns(status).once

      thread = mock("thread")
      thread.stubs(:name=)
      thread.stubs(:join)

      stdin = StringIO.new
      stdout = StringIO.new("stdout 1\nstdout 2")
      stderr = StringIO.new("stderr 1\nstderr 2")
      Open3.expects(:popen3)
        .with { |env, *command| command.include?("--schema=public") }
        .yields(stdin, stdout, stderr, thread).once

      dumper = described_class.new
      dumper.dump_schema(io)

      expect(io.string).to eq(stdout.string)
      expect(dumper.log_lines).to eq(stderr.string.split("\n"))
    end

    context "with real pg_dump" do
      # before(:context) and after(:context) runs outside of transaction
      before(:context) do
        DB.exec(<<~SQL)
          CREATE SCHEMA backup_test;

          CREATE TABLE backup_test.foo
          (
              id integer NOT NULL
          );

          CREATE VIEW backup_test.pg_stat_statements AS
          SELECT * FROM backup_test.foo;

          ALTER TABLE backup_test.pg_stat_statements OWNER TO postgres;
        SQL
      end

      after(:context) do
        DB.exec("DROP SCHEMA IF EXISTS backup_test CASCADE")
      end

      it "successfully dumps a database schema into a gzipped stream" do
        dumper = described_class.new(schema: "backup_test")
        dumper.dump_schema(io)

        db_dump = Zlib::gunzip(io.string)

        expect(db_dump).to include("CREATE TABLE backup_test.foo")
        expect(db_dump).to_not include("CREATE VIEW backup_test.pg_stat_statements")
      end
    end
  end
end
