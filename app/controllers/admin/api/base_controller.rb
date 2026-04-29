class Admin::Api::BaseController < ActionController::API
  before_action :authenticate_admin_token!

  private
    def authenticate_admin_token!
      expected = ENV["ADMIN_API_TOKEN"]
      provided = request.headers["X-Admin-Token"]

      if expected.blank?
        Rails.logger.error("[Admin::Api] ADMIN_API_TOKEN not configured; refusing request")
        head :service_unavailable and return
      end

      unless provided.present? && ActiveSupport::SecurityUtils.secure_compare(expected, provided)
        head :unauthorized and return
      end
    end
end
