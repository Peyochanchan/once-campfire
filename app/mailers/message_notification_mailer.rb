class MessageNotificationMailer < ApplicationMailer
  SNIPPET_LENGTH = 200

  # Receives a pre-built EmailNotification::Bundle::Context Data — no ivar
  # mutation, no shared `load` method. The template walks @ctx.rooms.
  def bundle(context)
    @ctx = context
    mail to: @ctx.user.email_address, subject: @ctx.subject
  end
end
