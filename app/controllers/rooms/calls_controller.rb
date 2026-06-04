class Rooms::CallsController < ApplicationController
  include RoomScoped

  def show
    @room.call_participants.find_or_create_by!(user: Current.user) do |cp|
      cp.joined_at = Time.current
    end
    @video = params[:video].present?
    @other_participants = @room.call_participants.includes(:user).where.not(user: Current.user).map(&:user)
  end

  def create
    @room.call_participants.find_or_create_by!(user: Current.user) do |cp|
      cp.joined_at = Time.current
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to room_path(@room) }
    end
  end

  def status
    in_call = @room.call_participants.exists?(user: Current.user)
    render json: { in_call: in_call }
  end

  # Mint a short-lived LiveKit join token for the current user in this room.
  # Issued on demand at join time (instead of rendered in a data-attribute on
  # the call page) so the JWT never sits in DOM where browser extensions or
  # devtools-injected scripts can read it.
  def token
    render json: {
      token: CallParticipant.generate_token(room: @room, user: Current.user, avatar_url: fresh_user_avatar_path(Current.user)),
      url:   Rails.configuration.x.livekit.url
    }
  end

  def destroy
    @room.call_participants.find_by(user: Current.user)&.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to room_path(@room) }
    end
  end
end
