class Room::EmailNotificationJob < ApplicationJob
  ACTIVITY_OFFLINE_THRESHOLD = 30.minutes
  ACTIVITY_DEBOUNCE          = 15.minutes

  def perform(room_id, message_id)
    message = Message.find_by(id: message_id)
    return if message.nil?

    room = Room.find_by(id: room_id)
    return if room.nil?

    mentionee_ids = Set.new(message.mentionees.pluck(:id))

    candidate_memberships(room, message).each do |membership|
      mode = email_mode_for(membership, room, mentionee_ids)
      next if mode.nil?
      next unless within_debounce?(membership, mode)

      deliver(membership, message, mode)
    end
  end

  private
    def candidate_memberships(room, message)
      room.memberships
          .visible
          .where.not(user_id: message.creator_id)
          .joins(:user)
          .merge(User.without_bots.active)
          .where(users: { email_notifications_enabled: true })
          .where.not(users: { email_address: [ nil, "" ] })
          .includes(:user, :room)
    end

    def email_mode_for(membership, room, mentionee_ids)
      return nil if membership.involved_in_invisible? || membership.involved_in_nothing?
      return nil unless offline?(membership, threshold: 0.seconds)

      mentioned = mentionee_ids.include?(membership.user_id) || room.direct?
      if mentioned
        :mention
      elsif membership.involved_in_everything? && offline?(membership, threshold: ACTIVITY_OFFLINE_THRESHOLD)
        :activity
      end
    end

    def offline?(membership, threshold:)
      return true if membership.connected_at.nil?
      membership.connected_at < threshold.ago
    end

    def within_debounce?(membership, mode)
      return true if mode == :mention
      last = membership.last_email_notified_at
      last.nil? || last < ACTIVITY_DEBOUNCE.ago
    end

    def deliver(membership, message, mode)
      MessageNotificationMailer.public_send(mode, membership.id, message.id).deliver_now
      membership.update_column(:last_email_notified_at, Time.current)
    rescue StandardError => e
      Rails.logger.error "[EmailNotificationJob] failed for membership=#{membership.id} message=#{message.id}: #{e.class} #{e.message}"
      Sentry.capture_exception(e, extra: { membership_id: membership.id, message_id: message.id }) if defined?(Sentry)
    end
end
