class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create verify confirm ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render_rejection :too_many_requests }
  rate_limit to: 10, within: 3.minutes, only: :confirm, with: -> { render_rejection :too_many_requests }

  before_action :ensure_user_exists, only: :new

  def new
  end

  def create
    if user = User.active.authenticate_by(email_address: params[:email_address], password: params[:password])
      session_record = user.sessions.start!(user_agent: request.user_agent, ip_address: request.remote_ip)
      session_record.generate_otp!
      SessionMailer.otp_code(session_record).deliver_later

      session[:pending_session_id] = session_record.id
      redirect_to verify_session_path
    else
      render_rejection :unauthorized
    end
  end

  def verify
    @pending_session = Session.find_by(id: session[:pending_session_id])
    redirect_to new_session_url unless @pending_session&.pending_verification?
  end

  def confirm
    @pending_session = Session.find_by(id: session[:pending_session_id])

    if @pending_session.nil? || @pending_session.otp_expired?
      @pending_session&.destroy
      session.delete(:pending_session_id)
      redirect_to new_session_url, alert: "Code expired. Please sign in again."
      return
    end

    if @pending_session.verify_otp(params[:otp_code])
      session.delete(:pending_session_id)
      authenticated_as @pending_session
      redirect_to post_authenticating_url
    else
      flash.now[:alert] = "Invalid code. Please try again."
      render :verify, status: :unprocessable_entity
    end
  end

  def destroy
    remove_push_subscription
    terminate_current_session
    redirect_to root_url
  end

  private
    def ensure_user_exists
      redirect_to first_run_url if User.none?
    end

    def render_rejection(status)
      flash.now[:alert] = "Too many requests or unauthorized."
      render :new, status: status
    end

    def remove_push_subscription
      if endpoint = params[:push_subscription_endpoint]
        Push::Subscription.destroy_by(endpoint: endpoint, user_id: Current.user.id)
      end
    end
end
