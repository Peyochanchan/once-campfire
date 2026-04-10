module Message::Broadcasts
  def broadcast_create
    if reply?
      broadcast_append_to room, :messages, target: "thread-replies", partial: "messages/message"
      # Also update the thread indicator on the parent message
      broadcast_replace_to room, :messages,
        target: "#{ActionView::RecordIdentifier.dom_id(parent_message)}_thread_indicator",
        partial: "messages/thread_indicator",
        locals: { message: parent_message }
    else
      broadcast_append_to room, :messages, target: [ room, :messages ]
    end
    ActionCable.server.broadcast("unread_rooms", { roomId: room.id })
  end

  def broadcast_remove
    broadcast_remove_to room, :messages
  end
end
