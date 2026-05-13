class MessageNotificationMailer < ApplicationMailer
  SNIPPET_LENGTH = 200

  def mention(membership_id, message_id)
    return unless load(membership_id, message_id)

    mail to: @user.email_address,
         subject: I18n.t("message_notifications.mailer.mention.subject",
                         sender: @sender.name, room: @room.name.presence || @app_name)
  end

  def activity(membership_id, message_id)
    return unless load(membership_id, message_id)

    mail to: @user.email_address,
         subject: I18n.t("message_notifications.mailer.activity.subject",
                         room: @room.name.presence || @app_name)
  end

  private
    def load(membership_id, message_id)
      @membership = Membership.find_by(id: membership_id)
      @message    = Message.find_by(id: message_id)
      return false if @membership.nil? || @message.nil?

      @user     = @membership.user
      @room     = @membership.room
      @sender   = @message.creator
      @app_name = Account.first&.name.presence || Rails.configuration.x.app.name
      @snippet  = @message.plain_text_body.to_s.truncate(SNIPPET_LENGTH)
      @room_url = room_url(@room)
      true
    end
end
