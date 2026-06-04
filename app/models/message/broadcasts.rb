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
    broadcast_unread_to_room_members
  end

  def broadcast_remove
    broadcast_remove_to room, :messages
  end

  private
    # Fan out the unread notification to room members only. The previous
    # implementation broadcast to a single global "unread_rooms" stream — every
    # connected user (any account) received every message's room.id, leaking
    # cross-tenant activity even though the JS controller filtered it out
    # client-side. Per-user stream scoping closes that leak.
    def broadcast_unread_to_room_members
      payload = { roomId: room.id }
      room.users.distinct.pluck(:id).each do |user_id|
        ActionCable.server.broadcast("user_#{user_id}_unread_rooms", payload)
      end
    end
end
