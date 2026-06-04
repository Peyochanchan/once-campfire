module EmailNotification::Dispatcher
  extend self

  GRACE_PERIOD       = 2.minutes
  PER_USER_COOLDOWN  = 1.minute
  PER_ROOM_COOLDOWN  = 5.minutes

  # Called when a message lands. Enumerate every membership in the room that
  # might want an email, ask Policy whether it's justified, skip silently if a
  # per-room cooldown is still in effect, otherwise create a pending row and
  # arm a DeliveryJob for the bundling window.
  def dispatch(message)
    candidates_for(message).find_each do |membership|
      verdict = EmailNotification::Policy.decide(message: message, membership: membership)
      next if verdict.action == :skip
      next if room_cooldown_active?(membership)

      PendingEmailNotification.create!(
        user_id:    membership.user_id,
        room_id:    message.room_id,
        message_id: message.id,
        kind:       verdict.kind.to_s
      )

      EmailNotification::DeliveryJob
        .set(wait: GRACE_PERIOD)
        .perform_later(membership.user_id)
    end
  end

  # Fired GRACE_PERIOD after a pending notification is created. Loads everything
  # still pending for the user, double-checks they're really still away, builds
  # a single email bundle and clears the queue. Idempotent — if N jobs fire for
  # the same user the first one drains, subsequent ones see an empty queue and
  # no-op.
  def deliver_bundle_for(user_id)
    user = User.find_by(id: user_id)
    return if user.nil? || !user.active?     # status enum (account active)
    return if user.recently_seen?            # they came back — let the unread badge do its job
    return if user_cooldown_active?(user)

    pendings = PendingEmailNotification.for_user(user_id).order(:created_at).to_a
    return if pendings.empty?

    context = EmailNotification::Bundle.build(user: user, message_ids: pendings.map(&:message_id))
    if context.nil?
      # All referenced messages were destroyed between insert and delivery —
      # nothing to send, just clear the queue.
      PendingEmailNotification.where(id: pendings.map(&:id)).delete_all
      return
    end

    MessageNotificationMailer.bundle(context).deliver_now

    now = Time.current
    PendingEmailNotification.where(id: pendings.map(&:id)).delete_all
    user.update_column(:last_email_notified_at, now)
    Membership.where(user_id: user_id, room_id: pendings.map(&:room_id).uniq)
              .update_all(last_email_notified_at: now)
  rescue StandardError => e
    Rails.logger.error "[EmailNotification::Dispatcher] deliver_bundle_for(#{user_id}) failed: #{e.class} #{e.message}"
    Sentry.capture_exception(e, extra: { user_id: user_id }) if defined?(Sentry)
  end

  private
    def candidates_for(message)
      message.room.memberships
        .visible
        .joins(:user)
        .merge(User.without_bots.active)
        .where(users: { email_notifications_enabled: true })
        .where.not(users: { email_address: [ nil, "" ] })
        .where.not(user_id: message.creator_id)
        .includes(:user, :room)
    end

    def room_cooldown_active?(membership)
      membership.last_email_notified_at.present? &&
        membership.last_email_notified_at > PER_ROOM_COOLDOWN.ago
    end

    def user_cooldown_active?(user)
      user.last_email_notified_at.present? &&
        user.last_email_notified_at > PER_USER_COOLDOWN.ago
    end
end
