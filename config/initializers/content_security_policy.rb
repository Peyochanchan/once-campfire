Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :blob, "https://*.your-objectstorage.com"
    policy.object_src  :none
    policy.script_src  :self, :unsafe_inline, :wasm_unsafe_eval, "https://cdn.jsdelivr.net"
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self, :wss, "https://cdn.jsdelivr.net", "https://storage.googleapis.com"
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
