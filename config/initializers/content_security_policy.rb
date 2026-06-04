Rails.application.configure do
  # LiveKit signaling endpoint (configured per-deploy via LIVEKIT_URL env).
  # Used in connect-src so ActionCable (:self) + LiveKit WS are allowed but the
  # previous `:wss` wildcard (= any wss host on the web) is rejected.
  livekit_url = Rails.configuration.x.livekit.url.to_s.presence

  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :blob, "https://*.your-objectstorage.com"
    policy.object_src  :none
    # script-src :unsafe_inline is still needed for a handful of inline scripts
    # in views/{users/profiles,messages,rooms/chat_embeds}. Migrating to
    # nonce-based CSP is deferred to a follow-up lot.
    policy.script_src  :self, :unsafe_inline, :wasm_unsafe_eval, "https://cdn.jsdelivr.net"
    # style-src :unsafe_inline is still needed for `style="--var: ..."` overrides
    # in messages/boosts views — same follow-up.
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self, *Array(livekit_url), "https://cdn.jsdelivr.net", "https://storage.googleapis.com"
    policy.worker_src  :self, :blob, "https://cdn.jsdelivr.net"
    policy.media_src   :self, :blob, "https://*.your-objectstorage.com"
    policy.frame_src   :self
    policy.child_src   :self, :blob
    policy.frame_ancestors :self
  end

  # Upgrade HTTP to HTTPS in production
  config.content_security_policy do |policy|
    policy.upgrade_insecure_requests true
  end if Rails.env.production?
end
