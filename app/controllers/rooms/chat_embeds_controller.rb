class Rooms::ChatEmbedsController < ApplicationController
  include RoomScoped

  layout "chat_embed"

  def show
    @messages = @room.messages.ordered.last(50)
  end
end
