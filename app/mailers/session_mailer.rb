class SessionMailer < ApplicationMailer
  def otp_code(session)
    @session = session
    @code = session.otp_code
    @user = session.user

    mail(
      to: @user.email_address,
      subject: "#{Rails.configuration.x.app.name} — Your verification code: #{@code}"
    )
  end
end
