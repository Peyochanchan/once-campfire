module Message::Mentionee
  extend ActiveSupport::Concern

  GLOBAL_ALL_PATTERN  = /(?<!\S)@(everyone|channel)\b/i
  GLOBAL_HERE_PATTERN = /(?<!\S)@here\b/i

  def mentionees
    return room.users.where(id: mentioned_user_ids) if room.direct?

    if global_mention_all?
      room.users.where.not(id: creator_id)
    elsif global_mention_here?
      ids = (mentioned_user_ids + connected_user_ids).uniq - [ creator_id ]
      room.users.where(id: ids)
    else
      room.users.where(id: mentioned_user_ids)
    end
  end

  def global_mention_all?
    plain_text_body.match?(GLOBAL_ALL_PATTERN)
  end

  def global_mention_here?
    plain_text_body.match?(GLOBAL_HERE_PATTERN)
  end

  private
    def mentioned_user_ids
      mentioned_users.map(&:id)
    end

    def mentioned_users
      if body.body
        body.body.attachables.grep(User).uniq
      else
        []
      end
    end

    def connected_user_ids
      Membership.connected.where(room_id: room.id).pluck(:user_id)
    end
end
