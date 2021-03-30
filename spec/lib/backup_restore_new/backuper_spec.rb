# frozen_string_literal: true

require 'rails_helper'

describe BackupRestoreNew::Backuper do
  fab!(:admin) { Fabricate(:admin) }
  let!(:logger) do
    Class.new(BackupRestoreNew::Logger::Base) do
      def log(message, level: nil); end
    end.new
  end

  subject { described_class.new(admin.id, logger) }

  def execute_stubbed_backup(site_name: "discourse")
    date_string = "2021-03-24T20:27:31Z"
    freeze_time(Time.parse(date_string))

    filenames = []
    output_streams = []
    tar_writer = expect_tar_creation(site_name)

    expect_db_dump_added_to_tar(filenames, output_streams)
    expect_uploads_added_to_tar(filenames, output_streams)
    expect_optimized_images_added_to_tar(filenames, output_streams)
    expect_metadata_added_to_tar(filenames, output_streams)
    expect_add_file_from_stream_calls(tar_writer, filenames, output_streams)

    subject.run
  end

  def expect_tar_creation(site_name)
    tar_writer = mock("tar_writer")
    current_db = RailsMultisite::ConnectionManagement.current_db
    filename = File.join(Rails.root, "public", "backups", current_db, "#{site_name}-2021-03-24-202731.tar")
    MiniTarball::Writer.expects(:create).with(filename).yields(tar_writer)
    tar_writer
  end

  def expect_db_dump_added_to_tar(filenames, output_streams)
    output_stream = mock("db_dump_output_stream")
    BackupRestoreNew::Backup::DatabaseDumper.any_instance.expects(:dump_schema).with(output_stream).once
    filenames << "dump.sql.gz"
    output_streams << output_stream
  end

  def expect_uploads_added_to_tar(filenames, output_streams)
    output_stream = mock("uploads_stream")
    BackupRestoreNew::Backup::UploadBackuper.any_instance.expects(:compress_uploads).with(output_stream).returns({ failed_ids: [] }).once
    filenames << "uploads.tar.gz"
    output_streams << output_stream
  end

  def expect_optimized_images_added_to_tar(filenames, output_streams)
    output_stream = mock("optimized_images_stream")
    BackupRestoreNew::Backup::UploadBackuper.any_instance.expects(:compress_optimized_images).with(output_stream).returns({ failed_ids: [] }).once
    filenames << "optimized-images.tar.gz"
    output_streams << output_stream
  end

  def expect_metadata_added_to_tar(filenames, output_streams)
    output_stream = mock("metadata_stream")
    BackupRestoreNew::Backup::MetadataWriter.any_instance.expects(:write).with(output_stream).once
    filenames << "meta.json"
    output_streams << output_stream
  end

  def expect_add_file_from_stream_calls(tar_writer, filenames, output_streams)
    expectation = tar_writer.expects(:add_file_from_stream).with do |args|
      true
    end

    output_streams.each do |output_stream|
      expectation = expectation.yields(output_stream)
    end

    expectation.times(filenames.size)
  end

  it "successfully creates a backup" do
    execute_stubbed_backup
  end
end
