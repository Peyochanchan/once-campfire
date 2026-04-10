class Rooms::MutesController < ApplicationController
  include RoomScoped

  def create
    membership.update!(muted: true)
    redirect_to room_path(@room)
  end

  def destroy
    membership.update!(muted: false)
    redirect_to room_path(@room)
  end

  private
    def membership
      @membership ||= Current.user.memberships.find_by!(room: @room)
    end
end
