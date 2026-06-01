module WebPush::Notification
  extend self

  def deliver(title:, body:, path:, badge:, endpoint:, p256dh_key:, auth_key:, connection: nil)
    WebPush.payload_send \
      message: encoded_message(title: title, body: body, path: path, badge: badge),
      endpoint: endpoint, p256dh: p256dh_key, auth: auth_key,
      vapid: vapid_identification,
      connection: connection,
      urgency: "high"
  end

  private
    def vapid_identification
      { subject: "mailto:support@37signals.com" }.merge \
        Rails.configuration.x.vapid.symbolize_keys
    end

    def encoded_message(title:, body:, path:, badge:)
      JSON.generate title: title, options: { body: body, icon: icon_path, data: { path: path, badge: badge } }
    end

    def icon_path
      Rails.application.routes.url_helpers.account_logo_path
    end
end
