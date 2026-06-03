class Users::ProfilesController < ApplicationController
  before_action :set_user

  def show
    @direct_memberships, @shared_memberships =
      Current.user.memberships.with_ordered_room.partition { |m| m.room.direct? }
  end

  def update
    if sensitive_change? && !current_password_valid?
      return redirect_to user_profile_url, alert: t("profile.current_password_required")
    end

    rotate_sessions = sensitive_change?

    @user.update user_params

    if rotate_sessions
      @user.sessions.where.not(id: Current.session&.id).destroy_all
    end

    redirect_to user_profile_url, notice: update_notice
  end

  private
    def set_user
      @user = Current.user
    end

    def user_params
      params.require(:user).permit(:name, :avatar, :email_address, :password, :bio, :ringtone, :locale,
                                   :custom_status, :custom_status_text, :custom_status_emoji,
                                   :email_notifications_enabled).compact
    end

    def update_notice
      params[:user][:avatar] ? t("profile.avatar_update_notice") : t("profile.update_success")
    end

    def sensitive_change?
      changing_password? || changing_email?
    end

    def changing_password?
      params.dig(:user, :password).present?
    end

    def changing_email?
      new_email = params.dig(:user, :email_address)
      new_email.present? && new_email != @user.email_address
    end

    def current_password_valid?
      cp = params[:current_password].to_s
      cp.present? && @user.authenticate(cp)
    end
end
