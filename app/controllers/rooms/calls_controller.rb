class Rooms::CallsController < ApplicationController
  include RoomScoped

  def show
    @room.call_participants.find_or_create_by!(user: Current.user) do |cp|
      cp.joined_at = Time.current
    end
    @token = CallParticipant.generate_token(room: @room, user: Current.user, avatar_url: fresh_user_avatar_path(Current.user))
    @video = params[:video].present?
  end

  def create
    @room.call_participants.find_or_create_by!(user: Current.user) do |cp|
      cp.joined_at = Time.current
    end
    @token = CallParticipant.generate_token(room: @room, user: Current.user, avatar_url: fresh_user_avatar_path(Current.user))

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to room_path(@room) }
    end
  end

  def destroy
    @room.call_participants.find_by(user: Current.user)&.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to room_path(@room) }
    end
  end
end
