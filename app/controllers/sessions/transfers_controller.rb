class Sessions::TransfersController < ApplicationController
  allow_unauthenticated_access

  def show
  end

  def update
    if user = User.active.find_by_transfer_id(params[:id])
      session_record = start_new_session_for user
      session_record.update!(verified: true)
      redirect_to post_authenticating_url
    else
      head :bad_request
    end
  end
end
