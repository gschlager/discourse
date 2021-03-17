# frozen_string_literal: true

module UploadsHelpers
  def setup_s3
    SiteSetting.enable_s3_uploads = true

    SiteSetting.s3_region = 'us-west-1'
    SiteSetting.s3_upload_bucket = "s3-upload-bucket"

    SiteSetting.s3_access_key_id = "some key"
    SiteSetting.s3_secret_access_key = "some secrets3_region key"

    stub_request(:head, "https://#{SiteSetting.s3_upload_bucket}.s3.#{SiteSetting.s3_region}.amazonaws.com/")
  end

  def enable_secure_media
    setup_s3
    SiteSetting.secure_media = true
  end

  def stub_upload(upload)
    url = "https://#{SiteSetting.s3_upload_bucket}.s3.#{SiteSetting.s3_region}.amazonaws.com/original/1X/#{upload.sha1}.#{upload.extension}?acl"
    stub_request(:put, url)
  end

  def stub_s3_store(stub_s3_responses: false)
    store = FileStore::S3Store.new
    client = Aws::S3::Client.new(stub_responses: true)
    store.s3_helper.stubs(:s3_client).returns(client)
    Discourse.stubs(:store).returns(store)
    FileStore::S3Store.stubs(:new).returns(store)

    if stub_s3_responses
      @s3_objects = {}

      client.stub_responses(:put_object, -> (context) do
        body = context.params[:body].read

        @s3_objects[context.params[:key]] = {
          body: body,
          size: body.bytesize,
          last_modified: Time.zone.now
        }
        { etag: Digest::MD5.hexdigest(body) }
      end)

      client.stub_responses(:head_object, -> (context) do
        if object = @s3_objects[context.params[:key]]
          { content_length: object[:size], last_modified: object[:last_modified] }
        else
          { status_code: 404, headers: {}, body: "", }
        end
      end)

      client.stub_responses(:get_object, -> (context) do
        if object = @s3_objects[context.params[:key]]
          { content_length: object[:size], body: object[:body] }
        else
          { status_code: 404, headers: {}, body: "" }
        end
      end)

      client
    end
  end
end
