# Prefix all S3 keys with a folder to organize files in the shared bucket.
# e.g. "abc123" becomes "campfire/abc123"
Rails.application.config.after_initialize do
  if Rails.env.production? && ENV["S3_ACCESS_KEY_ID"].present?
    prefix = ENV.fetch("S3_KEY_PREFIX", "campfire")

    require "active_storage/service/s3_service"

    ActiveStorage::Service::S3Service.prepend(Module.new do
      define_method(:object_for) do |key|
        super("#{prefix}/#{key}")
      end
    end)

    Rails.logger.info "[ActiveStorage] S3 prefix '#{prefix}/' configured"
    Rails.logger.info "[ActiveStorage] Bucket: #{ENV['S3_BUCKET']}"
    Rails.logger.info "[ActiveStorage] Endpoint: #{ENV['S3_ENDPOINT']}"
  end
end
