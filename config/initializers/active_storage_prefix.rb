Rails.application.config.after_initialize do
  if Rails.env.production?
    ActiveStorage::Blob.class_eval do
      before_create do
        unless key.start_with?("campfire/")
          self.key = "campfire/#{key}"
          Rails.logger.info "[ActiveStorage] Prefixed blob key: #{key} (service: #{service_name})"
        end
      end
    end

    Rails.logger.info "[ActiveStorage] S3 prefix 'campfire/' configured"
    Rails.logger.info "[ActiveStorage] Service: #{Rails.configuration.active_storage.service}"
    Rails.logger.info "[ActiveStorage] Bucket: #{ENV['S3_BUCKET']}"
    Rails.logger.info "[ActiveStorage] Endpoint: #{ENV['S3_ENDPOINT']}"
    Rails.logger.info "[ActiveStorage] Region: #{ENV['S3_REGION']}"
    Rails.logger.info "[ActiveStorage] Access Key present: #{ENV['S3_ACCESS_KEY_ID'].present?}"
  end
end
