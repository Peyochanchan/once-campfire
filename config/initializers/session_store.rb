Rails.application.config.session_store :cookie_store,
  key: "_campfire_session",
  # Persist session cookie as permament so re-opened browser windows maintain a CSRF token
  expire_after: 1.year,
  httponly: true,
  same_site: :lax,
  # `secure` follows force_ssl in production. force_ssl is currently disabled
  # via `DISABLE_SSL=true` env (set by deploy.yml) because Caddy terminates TLS
  # in front. Setting `secure: Rails.env.production?` is therefore safe — the
  # browser will only send the cookie over HTTPS without breaking dev.
  secure: Rails.env.production?
