# frozen_string_literal: true

require 'rails_helper'
require 'rubygems/package'

describe BackupRestoreNew::Backup::UploadBackuper do
  fab!(:user) { Fabricate(:user) }
  let(:io) { StringIO.new }

  def create_uploads(fixtures)
    uploads = fixtures.map do |filename, file|
      UploadCreator.new(file, filename).create_for(user.id)
    end

    paths = uploads.map do |upload|
      "original/1X/#{upload.sha1}.#{upload.extension}"
    end

    files = fixtures.values.map do |file|
      File.open(file.path, "rb").read
    end

    [paths, files]
  end

  def uncompress
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

  context "local uploads" do
    subject { described_class.new("", BackupRestoreNew::Logger::BaseProgressLogger.new) }

    it "works" do
      SiteSetting.authorized_extensions = 'png|pdf'

      upload_paths, uploaded_files = create_uploads(
        "logo.png" => file_from_fixtures("smallest.png"),
        "some.pdf" => file_from_fixtures("small.pdf", "pdf")
      )

      subject.compress_uploads(io)
      uncompressed_paths, uncompressed_files = uncompress

      expect(uncompressed_paths).to eq(upload_paths)
      expect(uncompressed_files).to eq(uploaded_files)
      expect(subject.errors).to be_blank
    end
  end
end
