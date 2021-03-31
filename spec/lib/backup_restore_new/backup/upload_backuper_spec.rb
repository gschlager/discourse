# frozen_string_literal: true

require 'rails_helper'
require 'rubygems/package'

describe BackupRestoreNew::Backup::UploadBackuper do
  before do
    SiteSetting.authorized_extensions = 'png|pdf'
  end

  def create_uploads(fixtures)
    uploads = fixtures.map do |filename, file|
      upload = UploadCreator.new(file, filename).create_for(Discourse::SYSTEM_USER_ID)
      raise "invalid upload" if upload.errors.present?
      upload
    end

    paths = uploads.map { |upload| "original/1X/#{upload.sha1}.#{upload.extension}" }
    files = fixtures.values.map { |file| File.open(file.path, "rb").read }
    [paths, files]
  end

  def create_optimized_images(fixtures)
    store = Discourse.store

    fixtures.map do |filename, file|
      upload = UploadCreator.new(file, filename).create_for(Discourse::SYSTEM_USER_ID)
      raise "invalid upload" if upload.errors.present?

      optimized_image = OptimizedImage.create_for(upload, 10, 10)
      prefixed_path = store.get_path_for_optimized_image(optimized_image)
      path = prefixed_path.delete_prefix("/#{store.upload_path}/")

      file = if SiteSetting.enable_s3_uploads
        @s3_objects[path][:body]
      else
        File.open(File.join(store.public_dir, prefixed_path), "rb").read
      end

      [path, file]
    end.transpose
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

  describe ".include_uploads?" do
    context "without uploads by users" do
      it "always returns false" do
        expect(described_class.include_uploads?).to eq(false)
      end
    end

    context "with local uploads by users" do
      before { Fabricate(:upload) }

      it "always returns true" do
        SiteSetting.include_s3_uploads_in_backups = false
        expect(described_class.include_uploads?).to eq(true)

        SiteSetting.include_s3_uploads_in_backups = true
        expect(described_class.include_uploads?).to eq(true)
      end
    end

    context "with uploads by users stored on S3" do
      before do
        setup_s3
        Fabricate(:upload_s3)
      end

      it "returns true when include_s3_uploads_in_backups is enabled" do
        SiteSetting.include_s3_uploads_in_backups = true
        expect(described_class.include_uploads?).to eq(true)
      end

      it "returns false when include_s3_uploads_in_backups is disabled" do
        SiteSetting.include_s3_uploads_in_backups = false
        expect(described_class.include_uploads?).to eq(false)
      end
    end
  end

  describe ".include_optimized_images?" do
    context "without uploads by users" do
      it "always returns false" do
        SiteSetting.include_thumbnails_in_backups = true
        expect(described_class.include_optimized_images?).to eq(false)

        SiteSetting.include_thumbnails_in_backups = false
        expect(described_class.include_optimized_images?).to eq(false)
      end
    end

    context "with uploads by users" do
      before { Fabricate(:optimized_image) }

      it "returns true when include_thumbnails_in_backups is enabled" do
        SiteSetting.include_thumbnails_in_backups = true
        expect(described_class.include_optimized_images?).to eq(true)
      end

      it "returns false when include_thumbnails_in_backups is disabled" do
        SiteSetting.include_thumbnails_in_backups = false
        expect(described_class.include_optimized_images?).to eq(false)
      end
    end
  end

  describe "#compress_uploads" do
    before { @tmp_directory = Dir.mktmpdir }
    after { FileUtils.rm_rf(@tmp_directory) }
    subject { described_class.new(@tmp_directory, BackupRestoreNew::Logger::BaseProgressLogger.new) }

    shared_examples "compression and error logging" do
      it "compresses existing files and logs missing files" do
        io = StringIO.new
        missing_upload1 = Fabricate(upload_type)

        upload_paths, uploaded_files = create_uploads(
          "smallest.png" => file_from_fixtures("smallest.png"),
          "small.pdf" => file_from_fixtures("small.pdf", "pdf")
        )

        missing_upload2 = Fabricate(upload_type)

        result = subject.compress_uploads(io)
        uncompressed_paths, uncompressed_files = uncompress(io)

        expect(uncompressed_paths).to eq(upload_paths)
        expect(uncompressed_files).to eq(uploaded_files)
        expect(result[:total_count]).to eq(4)
        expect(result[:included_count]).to eq(2)
        expect(result[:failed_ids]).to contain_exactly(missing_upload1.id, missing_upload2.id)
      end
    end

    context "local uploads" do
      let!(:upload_type) { :upload }

      include_examples "compression and error logging"
    end

    context "S3 uploads" do
      before do
        setup_s3
        stub_s3_store(stub_s3_responses: true)
      end

      let!(:upload_type) { :upload_s3 }

      include_examples "compression and error logging"
    end

    context "mixed uploads" do
      it "compresses existing files and logs missing files" do
        local_upload_paths, local_uploaded_files = create_uploads(
          "smallest.png" => file_from_fixtures("smallest.png")
        )
        setup_s3
        stub_s3_store(stub_s3_responses: true)
        s3_upload_paths, s3_uploaded_files = create_uploads(
          "small.pdf" => file_from_fixtures("small.pdf", "pdf")
        )
        upload_paths = local_upload_paths + s3_upload_paths
        uploaded_files = local_uploaded_files + s3_uploaded_files

        io = StringIO.new
        result = subject.compress_uploads(io)
        uncompressed_paths, uncompressed_files = uncompress(io)

        expect(uncompressed_paths).to eq(upload_paths)
        expect(uncompressed_files).to eq(uploaded_files)
        expect(result[:total_count]).to eq(2)
        expect(result[:included_count]).to eq(2)
        expect(result[:failed_ids]).to be_blank

        SiteSetting.enable_s3_uploads = false
        io = StringIO.new
        result = subject.compress_uploads(io)
        uncompressed_paths, uncompressed_files = uncompress(io)

        expect(uncompressed_paths).to eq(upload_paths)
        expect(uncompressed_files).to eq(uploaded_files)
        expect(result[:total_count]).to eq(2)
        expect(result[:included_count]).to eq(2)
        expect(result[:failed_ids]).to be_blank
      end
    end
  end

  describe "#add_optimized_files" do
    subject { described_class.new(Dir.mktmpdir, BackupRestoreNew::Logger::BaseProgressLogger.new) }

    it "includes optimized images stored locally" do
      missing_image1 = Fabricate(:optimized_image)

      optimized_paths, optimized_files = create_optimized_images(
        "smallest.png" => file_from_fixtures("smallest.png"),
        "logo.png" => file_from_fixtures("logo.png")
      )

      missing_image2 = Fabricate(:optimized_image)

      io = StringIO.new
      result = subject.compress_optimized_images(io)
      uncompressed_paths, uncompressed_files = uncompress(io)

      expect(uncompressed_paths).to eq(optimized_paths)
      expect(uncompressed_files).to eq(optimized_files)
      expect(result[:total_count]).to eq(4)
      expect(result[:included_count]).to eq(2)
      expect(result[:failed_ids]).to contain_exactly(missing_image1.id, missing_image2.id)
    end

    it "doesn't include optimized images stored on S3" do
      setup_s3
      stub_s3_store(stub_s3_responses: true)

      create_optimized_images(
        "smallest.png" => file_from_fixtures("smallest.png"),
        "logo.png" => file_from_fixtures("logo.png")
      )

      io = StringIO.new
      result = subject.compress_optimized_images(io)
      uncompressed_paths, uncompressed_files = uncompress(io)

      expect(uncompressed_paths).to be_blank
      expect(uncompressed_files).to be_blank
      expect(result[:total_count]).to eq(2)
      expect(result[:included_count]).to eq(0)
      expect(result[:failed_ids]).to be_blank
    end
  end
end
