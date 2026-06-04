class Push::Subscription < ApplicationRecord
  # Major browser/OS push providers. Anything else is rejected to prevent the
  # /test_notifications endpoint (and the regular push delivery worker) from
  # being abused as an SSRF probe of internal services.
  ALLOWED_ENDPOINT_HOSTS = %w[
    fcm.googleapis.com
    web.push.apple.com
    updates.push.services.mozilla.com
  ].freeze

  ALLOWED_ENDPOINT_HOST_SUFFIXES = %w[
    .notify.windows.com
  ].freeze

  belongs_to :user

  validates :endpoint, presence: true
  validate  :endpoint_points_to_known_push_provider

  def notification_params(**params)
    params.merge(badge: user.memberships.unread.count, endpoint: endpoint, p256dh_key: p256dh_key, auth_key: auth_key)
  end

  private
    def endpoint_points_to_known_push_provider
      uri = URI.parse(endpoint.to_s)
      unless uri.is_a?(URI::HTTPS)
        errors.add(:endpoint, "must be an HTTPS URL")
        return
      end
      host = uri.host.to_s.downcase
      ok = ALLOWED_ENDPOINT_HOSTS.include?(host) ||
           ALLOWED_ENDPOINT_HOST_SUFFIXES.any? { |suffix| host.end_with?(suffix) }
      errors.add(:endpoint, "host not in push provider allowlist") unless ok
    rescue URI::InvalidURIError
      errors.add(:endpoint, "invalid URL")
    end
end
