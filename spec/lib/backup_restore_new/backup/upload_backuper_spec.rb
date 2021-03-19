# frozen_string_literal: true

require 'rails_helper'
require 'rubygems/package'

describe BackupRestoreNew::Backup::UploadBackuper do
  fab!(:user) { Fabricate(:user) }

  before do
    SiteSetting.authorized_extensions = 'png|pdf'
  end

  def create_uploads(fixtures)
    uploads = fixtures.map do |filename, file|
      upload = UploadCreator.new(file, filename).create_for(user.id)
      raise "invalid upload" if upload.errors.present?

      upload
    end

    paths = uploads.map do |upload|
      "original/1X/#{upload.sha1}.#{upload.extension}"
    end

    files = fixtures.values.map do |file|
      File.open(file.path, "rb").read
    end

    [paths, files]
  end

  def uncompress(io)
    paths = []
    files = []

    Zlib::GzipReader.wrap(StringIO.new(io.string)) do |gz|
      Gem::Package::TarReader.new(gz) do |tar|
        tar.each do |entry|
          paths << entry.full_name
          files << entry.read
        end
      end
    end

    [paths, files]
  end

  shared_examples "compression and error logging" do
    it "compresses existing files and logs missing files" do
      io = StringIO.new
      missing_upload1 = Fabricate(upload_type)

      upload_paths, uploaded_files = create_uploads(
        "logo.png" => file_from_fixtures("smallest.png"),
        "some.pdf" => file_from_fixtures("small.pdf", "pdf")
      )

      missing_upload2 = Fabricate(upload_type)

      subject.compress_uploads(io)
      uncompressed_paths, uncompressed_files = uncompress(io)

      expect(uncompressed_paths).to eq(upload_paths)
      expect(uncompressed_files).to eq(uploaded_files)

      expect(subject.errors.size).to eq(2)
      expect(subject.errors[0][:message]).to include("ID #{missing_upload1.id}")
      expect(subject.errors[1][:message]).to include("ID #{missing_upload2.id}")
    end
  end

  context "local uploads" do
    subject { described_class.new("", BackupRestoreNew::Logger::BaseProgressLogger.new) }
    let!(:upload_type) { :upload }

    include_examples "compression and error logging"
  end

  context "S3 uploads" do
    before do
      setup_s3
      stub_s3_store(stub_s3_responses: true)
    end

    subject { described_class.new(Dir.mktmpdir, BackupRestoreNew::Logger::BaseProgressLogger.new) }
    let!(:upload_type) { :upload_s3 }

    include_examples "compression and error logging"
  end

  context "mixed uploads" do
    subject { described_class.new(Dir.mktmpdir, BackupRestoreNew::Logger::BaseProgressLogger.new) }

    it "compresses existing files and logs missing files" do
      local_upload_paths, local_uploaded_files = create_uploads(
        "logo.png" => file_from_fixtures("smallest.png")
      )
      setup_s3
      stub_s3_store(stub_s3_responses: true)
      s3_upload_paths, s3_uploaded_files = create_uploads(
        "some.pdf" => file_from_fixtures("small.pdf", "pdf")
      )
      upload_paths = local_upload_paths + s3_upload_paths
      uploaded_files = local_uploaded_files + s3_uploaded_files

      io = StringIO.new
      subject.compress_uploads(io)
      uncompressed_paths, uncompressed_files = uncompress(io)

      expect(uncompressed_paths).to eq(upload_paths)
      expect(uncompressed_files).to eq(uploaded_files)
      expect(subject.errors).to be_blank

      SiteSetting.enable_s3_uploads = false
      io = StringIO.new
      subject.compress_uploads(io)
      uncompressed_paths, uncompressed_files = uncompress(io)

      expect(uncompressed_paths).to eq(upload_paths)
      expect(uncompressed_files).to eq(uploaded_files)
      expect(subject.errors).to be_blank
    end
  end
end
