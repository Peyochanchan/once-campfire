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

  def update_by_email
    email = params[:email].to_s.downcase
    user = User.active.find_by("LOWER(email_address) = ?", email)

    if user.nil?
      Rails.logger.info("[Admin::Api] No active user with email=#{email} (idempotent update)")
      head :no_content and return
    end

    attrs = {}
    attrs[:name]   = params[:name]                                                      if params.key?(:name) && params[:name].present?
    attrs[:hidden] = ActiveModel::Type::Boolean.new.cast(params[:hidden])               if params.key?(:hidden)

    if attrs.any?
      user.update!(attrs)
      Rails.logger.info("[Admin::Api] Updated user id=#{user.id} email=#{email} attrs=#{attrs.keys}")
    end

    head :no_content
  end
end
