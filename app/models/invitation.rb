class Invitation < ApplicationRecord
  DEFAULT_EXPIRY = 7.days

  belongs_to :invited_by, class_name: "User"
  belongs_to :accepted_user, class_name: "User", optional: true
  belongs_to :room, optional: true

  validates :email, presence: true, format: URI::MailTo::EMAIL_REGEXP
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create
  before_validation :set_default_expiry, on: :create

  scope :ordered,  -> { order(created_at: :desc) }
  scope :pending,  -> { where(accepted_at: nil, revoked_at: nil).where("expires_at > ?", Time.current) }
  scope :accepted, -> { where.not(accepted_at: nil) }
  scope :expired,  -> { where("expires_at <= ? OR revoked_at IS NOT NULL", Time.current).where(accepted_at: nil) }

  def status
    return :revoked  if revoked_at?
    return :accepted if accepted_at?
    return :expired  if expires_at <= Time.current
    :pending
  end

  def pending?
    status == :pending
  end

  # Atomically accept the invitation. Returns true if successful, false if already accepted/revoked/expired.
  def accept!(user)
    transaction do
      # Atomic check + update — only updates if still pending
      updated = self.class.where(id: id, accepted_at: nil, revoked_at: nil)
                          .where("expires_at > ?", Time.current)
                          .update_all(accepted_user_id: user.id, accepted_at: Time.current, updated_at: Time.current)
      raise ActiveRecord::RecordNotFound, "Invitation already used or no longer valid" if updated.zero?

      reload
      # If invitation is room-scoped, grant access to that room
      room.memberships.find_or_create_by!(user: user) if room.present?
    end
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  private
    def generate_token
      self.token ||= SecureRandom.urlsafe_base64(32)
    end

    def set_default_expiry
      self.expires_at ||= DEFAULT_EXPIRY.from_now
    end
end
