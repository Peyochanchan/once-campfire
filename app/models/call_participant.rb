class CallParticipant < ApplicationRecord
  include ActionView::RecordIdentifier
  include TokenGeneration

  belongs_to :room
  belongs_to :user

  after_create_commit  :broadcast_call_state
  after_destroy_commit :broadcast_call_state

  private
    def broadcast_call_state
      broadcast_replace_to [ room, :call ],
        target: dom_id(room, :call_banner),
        partial: "rooms/calls/banner",
        locals: { room: room, user: Current.user }
    end
end
