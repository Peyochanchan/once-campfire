class OidcCallbacksController < ApplicationController
  allow_unauthenticated_access
  skip_forgery_protection only: :create

  def create
    auth = request.env["omniauth.auth"]
    user = find_or_create_user(auth)

    if user&.persisted?
      session_record = start_new_session_for user
      session_record.update!(verified: true)
      redirect_to root_url
    else
      redirect_to new_session_url, alert: t("auth.failed")
    end
  end

  def failure
    redirect_to new_session_url, alert: "Authentication failed: #{params[:message]}"
  end

  private
    def find_or_create_user(auth)
      sub = auth.uid
      provider = auth.provider.to_s
      info = auth.info

      # Find existing OIDC user
      user = User.find_by(oidc_sub: sub, oidc_provider: provider)
      return user if user

      # Auto-link to an existing local account by email is only allowed when the
      # IdP explicitly asserts the email has been verified. Otherwise an
      # attacker who registers `victim@corp` at an IdP with no email
      # verification could hijack the local victim account on first callback.
      user = User.find_by(email_address: info.email)
      if user
        return user if email_verified?(auth) && user.update(oidc_sub: sub, oidc_provider: provider)
        return nil
      end

      # Create new user — hidden by default so they don't appear in directories
      # until an admin makes them visible.
      User.create!(
        name: info.name || info.preferred_username || info.email.split("@").first,
        email_address: info.email,
        password: SecureRandom.hex(32),
        oidc_sub: sub,
        oidc_provider: provider,
        hidden: true
      )
    end

    def email_verified?(auth)
      info = auth.info
      raw  = auth.extra&.raw_info
      [ info.try(:email_verified), raw&.dig("email_verified"), raw&.dig(:email_verified) ].any? { |v| v == true || v == "true" }
    end
end
