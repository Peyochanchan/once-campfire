module EmailNotification::Bundle
  extend self

  Context    = Data.define(:user, :app_name, :rooms, :total_count, :subject)
  RoomBundle = Data.define(:room, :messages, :first_sender)

  def build(user:, message_ids:)
    return nil if Array(message_ids).empty?

    messages = Message.where(id: message_ids).includes(:room, :creator).order(:created_at).to_a
    return nil if messages.empty?

    name = app_name
    room_bundles = messages.group_by(&:room).map do |room, msgs|
      RoomBundle.new(room: room, messages: msgs, first_sender: msgs.first.creator)
    end

    Context.new(
      user:        user,
      app_name:    name,
      rooms:       room_bundles,
      total_count: messages.size,
      subject:     subject_for(messages, room_bundles, app_name: name)
    )
  end

  private
    def app_name
      Account.first&.name.presence || Rails.configuration.x.app.name
    end

    def subject_for(messages, room_bundles, app_name:)
      if messages.size == 1
        msg = messages.first
        if msg.room.is_a?(Rooms::Direct)
          I18n.t("message_notifications.mailer.bundle.subject.single_dm", sender: msg.creator.name)
        else
          I18n.t("message_notifications.mailer.bundle.subject.single",
                 sender: msg.creator.name,
                 room:   msg.room.name.presence || app_name)
        end
      elsif room_bundles.size == 1
        room = room_bundles.first.room
        I18n.t("message_notifications.mailer.bundle.subject.one_room_multi",
               count: messages.size,
               room:  room.name.presence || app_name)
      else
        I18n.t("message_notifications.mailer.bundle.subject.multi",
               count:      messages.size,
               room_count: room_bundles.size)
      end
    end
end
