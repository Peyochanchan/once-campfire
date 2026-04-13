class UsersController < ApplicationController
  require_unauthenticated_access only: %i[ new create ]

  before_action :set_user, only: :show
  before_action :verify_join_code, only: %i[ new create ]

  def new
    @user = User.new
  end

  def create
    @user = User.create!(user_params)
    session_record = @user.sessions.start!(user_agent: request.user_agent, ip_address: request.remote_ip)
    session_record.generate_otp!
    SessionMailer.otp_code(session_record).deliver_later

    session[:pending_session_id] = session_record.id
    redirect_to verify_session_path
  rescue ActiveRecord::RecordNotUnique
    redirect_to new_session_url(email_address: user_params[:email_address])
  end

  def show
  end

  private
    def set_user
      @user = User.find(params[:id])
    end

    def verify_join_code
      head :not_found if Current.account.join_code != params[:join_code]
    end

    def user_params
      params.require(:user).permit(:name, :avatar, :email_address, :password)
    end
end
