class Rack::Attack
  # Use Redis cache if available, otherwise memory store
  if ENV["REDIS_URL"].present?
    Rack::Attack.cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"])
  end

  # Behind a reverse proxy (Caddy / Kamal-Proxy / Nginx) the socket IP is the
  # proxy's, not the client's. Read X-Forwarded-For instead so throttle keys
  # are scoped to the real client. The first hop is the client; subsequent
  # entries are proxies appended along the way.
  class Request < ::Rack::Request
    def real_ip
      forwarded = env["HTTP_X_FORWARDED_FOR"]
      forwarded.present? ? forwarded.split(",").first.strip : ip
    end
  end

  ### Safelists ###

  # Allow health checks
  safelist("health-check") do |req|
    req.path == "/up"
  end

  # Allow assets
  safelist("assets") do |req|
    req.path.start_with?("/assets")
  end

  ### Throttles ###

  # General: 300 req/min per IP
  throttle("req/ip", limit: 300, period: 1.minute) do |req|
    req.real_ip unless req.path.start_with?("/assets", "/up")
  end

  # Login: 5 attempts per IP per 3 minutes
  throttle("logins/ip", limit: 5, period: 3.minutes) do |req|
    req.real_ip if req.path == "/session" && req.post?
  end

  # OTP: 5 attempts per IP per 3 minutes
  throttle("otp/ip", limit: 5, period: 3.minutes) do |req|
    req.real_ip if req.path == "/session/confirm" && req.post?
  end

  # User creation: 5 per IP per hour
  throttle("signup/ip", limit: 5, period: 1.hour) do |req|
    req.real_ip if req.path.match?(%r{^/join/}) && req.post?
  end

  # Throttle key for authenticated endpoints: session_token cookie when present
  # (signed cookie value, opaque but stable + unique per session), else IP.
  # Avoids penalising all users behind a shared VPN/CGNAT exit IP.
  authenticated_throttle_key = ->(req) { req.cookies["session_token"].presence || req.real_ip }

  # Messages: 24 per session (or IP) per minute (~ 1 message every 2.5 seconds)
  throttle("messages/session", limit: 24, period: 1.minute) do |req|
    authenticated_throttle_key.call(req) if req.path.match?(%r{^/rooms/\d+/messages$}) && req.post?
  end

  # Search: 30 per session (or IP) per minute
  throttle("search/session", limit: 30, period: 1.minute) do |req|
    authenticated_throttle_key.call(req) if req.path == "/searches" && req.post?
  end

  # User enumeration protection
  throttle("autocomplete/session", limit: 20, period: 1.minute) do |req|
    authenticated_throttle_key.call(req) if req.path.start_with?("/autocompletable")
  end

  # Invitation creation (account or room scoped): 20 per session (or IP) per hour
  throttle("invitations/session", limit: 20, period: 1.hour) do |req|
    authenticated_throttle_key.call(req) if (req.path == "/account/invitations" || req.path.match?(%r{^/rooms/\d+/invitations$})) && req.post?
  end

  # Invitation acceptance: 5 per IP per 5 minutes
  throttle("invitation_accept/ip", limit: 5, period: 5.minutes) do |req|
    req.real_ip if req.path.match?(%r{^/invite/\w+$}) && req.post?
  end

  ### Blocklists ###

  # Block suspicious paths
  blocklist("block-dangerous-paths") do |req|
    req.path.include?("..") ||
      req.path.match?(/\.(env|git|sql|bak|log)$/i) ||
      req.path.include?("wp-admin") ||
      req.path.include?("phpMyAdmin")
  end

  # Block after 10 failed login attempts per IP (1 hour ban)
  blocklist("login-failures/ip") do |req|
    Rack::Attack::Allow2Ban.filter("login-failures:#{req.real_ip}", maxretry: 10, findtime: 10.minutes, bantime: 1.hour) do
      req.path == "/session" && req.post? && req.env["rack.attack.match_type"].nil?
    end
  end

  ### Custom responses ###

  self.blocklisted_responder = lambda do |_req|
    [403, { "Content-Type" => "text/plain" }, ["Forbidden"]]
  end

  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [429, { "Content-Type" => "text/plain", "Retry-After" => retry_after.to_s }, ["Too many requests. Retry later."]]
  end
end
