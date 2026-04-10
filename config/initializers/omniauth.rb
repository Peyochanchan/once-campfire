Rails.application.config.middleware.use OmniAuth::Builder do
  if ENV["OIDC_CLIENT_ID"].present?
    provider :openid_connect,
      name: :keycloak,
      scope: %i[openid email profile],
      response_type: :code,
      issuer: ENV["OIDC_ISSUER_URL"] || ENV["KEYCLOAK_REALM_URL"],
      discovery: true,
      client_options: {
        identifier: ENV["OIDC_CLIENT_ID"],
        secret: ENV["OIDC_CLIENT_SECRET"],
        redirect_uri: ENV.fetch("OIDC_REDIRECT_URI", nil)
      }
  end
end

OmniAuth.config.logger = Rails.logger
OmniAuth.config.allowed_request_methods = [ :post ]
