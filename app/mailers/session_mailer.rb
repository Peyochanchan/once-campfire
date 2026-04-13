class SessionMailer < ApplicationMailer
  def otp_code(session)
    @session = session
    @code = session.otp_code
    @user = session.user
    @app_name = Account.first&.name.presence || Rails.configuration.x.app.name

    mail(
      to: @user.email_address,
      subject: "#{@app_name} — Your verification code: #{@code}"
    )
  end
end
