module ApplicationCable
  class Channel < ActionCable::Channel::Base
    # Touch User#last_seen_at on every subscribe. Since any open Campfire tab
    # subscribes at least to UnreadRoomsChannel (sidebar) and usually
    # HeartbeatChannel + RoomChannel, this is sufficient to track "user has
    # the app open globally" without per-room WebSocket gymnastics. Drives
    # User#recently_seen?, which the email bundle dispatcher reads to decide
    # whether to suppress an email (user came back, no need to email).
    def subscribed
      super
      current_user&.mark_seen!
    end
  end
end
