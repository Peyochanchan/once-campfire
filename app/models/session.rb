class Session < ApplicationRecord
  ACTIVITY_REFRESH_RATE = 1.hour
  INACTIVITY_TIMEOUT = 4.hours
  OTP_EXPIRY = 10.minutes

  has_secure_token

  belongs_to :user

  before_create { self.last_active_at ||= Time.now }

  def self.start!(user_agent:, ip_address:)
    create! user_agent: user_agent, ip_address: ip_address
  end

  def resume(user_agent:, ip_address:)
    if last_active_at.before?(ACTIVITY_REFRESH_RATE.ago)
      update! user_agent: user_agent, ip_address: ip_address, last_active_at: Time.now
    end
  end

  def generate_otp!
    update!(
      otp_code: SecureRandom.random_number(10**6).to_s.rjust(6, "0"),
      otp_sent_at: Time.current,
      verified: false
    )
  end

  def verify_otp(code)
    return false if otp_code.blank? || otp_sent_at.blank?
    return false if otp_sent_at < OTP_EXPIRY.ago
    return false unless ActiveSupport::SecurityUtils.secure_compare(otp_code.to_s, code.to_s)

    update!(verified: true, otp_code: nil)
    true
  end

  def otp_expired?
    otp_sent_at.present? && otp_sent_at < OTP_EXPIRY.ago
  end

  def pending_verification?
    !verified? && otp_code.present?
  end

  def expired?
    last_active_at.present? && last_active_at < INACTIVITY_TIMEOUT.ago
  end
end
