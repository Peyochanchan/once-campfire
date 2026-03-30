class CallParticipant < ApplicationRecord
  include ActionView::RecordIdentifier
  include TokenGeneration

  belongs_to :room
  belongs_to :user

  after_create_commit  :broadcast_participant_joined
  after_destroy_commit :broadcast_participant_left

  private
    def broadcast_participant_joined
      broadcast_replace_to [ room, :call ],
        target: dom_id(room, :call_banner),
        partial: "rooms/calls/banner",
        locals: { room: room, notify: true }
    end

    def broadcast_participant_left
      broadcast_replace_to [ room, :call ],
        target: dom_id(room, :call_banner),
        partial: "rooms/calls/banner",
        locals: { room: room, notify: false }
    end
end
