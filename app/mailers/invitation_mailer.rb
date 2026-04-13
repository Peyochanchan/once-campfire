class InvitationMailer < ApplicationMailer
  def invite(invitation)
    @invitation = invitation
    @invited_by = invitation.invited_by
    @app_name = Account.first&.name.presence || Rails.configuration.x.app.name
    @invitation_url = invitation_url(invitation.token)

    mail(
      to: invitation.email,
      subject: I18n.t("invitations.mailer.subject", inviter: @invited_by.name, app_name: @app_name)
    )
  end
end
