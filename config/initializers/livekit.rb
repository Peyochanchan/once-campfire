require "livekit"

Rails.application.configure do
  config.x.livekit.api_key    = ENV.fetch("LIVEKIT_API_KEY",    Rails.application.credentials.dig(:livekit, :api_key) || "devkey")
  config.x.livekit.api_secret = ENV.fetch("LIVEKIT_API_SECRET", Rails.application.credentials.dig(:livekit, :api_secret) || "secret")
  config.x.livekit.url        = ENV.fetch("LIVEKIT_URL",        Rails.application.credentials.dig(:livekit, :url) || "ws://localhost:7880")
end
