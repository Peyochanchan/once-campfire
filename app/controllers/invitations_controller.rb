class InvitationsController < ApplicationController
  require_unauthenticated_access

  before_action :set_invitation

  def show
    @user = User.new(email_address: @invitation.email)
  end

  def accept
    @user = User.new(user_params.merge(email_address: @invitation.email))

    if @user.save
      @invitation.accept!(@user)
      session_record = @user.sessions.start!(user_agent: request.user_agent, ip_address: request.remote_ip)
      session_record.generate_otp!
      SessionMailer.otp_code(session_record).deliver_later

      session[:pending_session_id] = session_record.id
      redirect_to verify_session_path
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def set_invitation
      @invitation = Invitation.find_by(token: params[:token])
      render :invalid, status: :not_found unless @invitation&.pending?
    end

    def user_params
      params.require(:user).permit(:name, :password, :avatar)
    end
end
