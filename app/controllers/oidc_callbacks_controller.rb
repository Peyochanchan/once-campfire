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
      redirect_to new_session_url, alert: "Authentication failed"
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

      # Find by email and link OIDC
      user = User.find_by(email_address: info.email)
      if user
        user.update!(oidc_sub: sub, oidc_provider: provider)
        return user
      end

      # Create new user
      User.create!(
        name: info.name || info.preferred_username || info.email.split("@").first,
        email_address: info.email,
        password: SecureRandom.hex(32),
        oidc_sub: sub,
        oidc_provider: provider
      )
    end
end
