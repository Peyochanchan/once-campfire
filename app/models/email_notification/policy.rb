module EmailNotification::Policy
  extend self

  # Decide whether sending an email is justified for one membership / one
  # message. Pure function — no side effects, no DB writes, no I/O beyond the
  # mentionees lookup. Returns an EmailNotification::Verdict.
  def decide(message:, membership:)
    return EmailNotification::Verdict.skip if same_user?(message, membership)
    return EmailNotification::Verdict.skip if muted_membership?(membership)
    return EmailNotification::Verdict.enqueue(:direct)  if direct_room?(membership.room)
    return EmailNotification::Verdict.enqueue(:mention) if mentioned?(message, membership)
    return EmailNotification::Verdict.enqueue(:activity) if all_activity?(membership)
    EmailNotification::Verdict.skip
  end

  private
    def same_user?(message, membership)
      message.creator_id == membership.user_id
    end

    def muted_membership?(membership)
      membership.involved_in_invisible? || membership.involved_in_nothing?
    end

    def direct_room?(room)
      room.is_a?(Rooms::Direct)
    end

    def mentioned?(message, membership)
      message.mentionees.exists?(id: membership.user_id)
    end

    def all_activity?(membership)
      membership.involved_in_everything?
    end
end
