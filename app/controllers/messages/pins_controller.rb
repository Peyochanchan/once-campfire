class Messages::PinsController < ApplicationController
  before_action :set_message

  def create
    @message.pin!
    broadcast_pinned_update
    redirect_to room_path(@message.room)
  end

  def destroy
    @message.unpin!
    broadcast_pinned_update
    redirect_to room_path(@message.room)
  end

  private
    def set_message
      @message = Current.user.reachable_messages.find(params[:message_id])
    end

    def broadcast_pinned_update
      Turbo::StreamsChannel.broadcast_replace_to(
        [@message.room, :messages],
        target: "pinned-messages",
        partial: "messages/pinned_bar",
        locals: { room: @message.room }
      )
    end
end
