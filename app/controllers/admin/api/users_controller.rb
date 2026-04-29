class Admin::Api::UsersController < Admin::Api::BaseController
  def destroy_by_email
    email = params[:email].to_s.downcase
    user = User.active.find_by("LOWER(email_address) = ?", email)

    if user.nil?
      Rails.logger.info("[Admin::Api] No active user with email=#{email} (idempotent)")
      head :no_content and return
    end

    user.deactivate
    Rails.logger.info("[Admin::Api] Deactivated user id=#{user.id} email=#{email}")
    head :no_content
  end
end
