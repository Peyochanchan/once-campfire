class Accounts::UsersController < ApplicationController
  before_action :ensure_can_administer, :set_user, only: %i[ update destroy ]

  def index
    set_page_and_extract_portion_from User.active.visible_to(Current.user).ordered.without_bots, per_page: 500
  end

  def update
    @user.update(user_params)
    redirect_to edit_account_url
  end

  def destroy
    @user.deactivate
    redirect_to edit_account_url
  end

  private
    def set_user
      @user = User.active.find(params[:user_id] || params[:id])
    end

    def user_params
      attrs = params.require(:user)
      result = {}
      result[:role] = attrs[:role].presence_in(%w[ member administrator ]) || "member" if attrs.key?(:role)
      result[:hidden] = ActiveModel::Type::Boolean.new.cast(attrs[:hidden]) if attrs.key?(:hidden)
      result
    end
end
