module User::Presence
  extend ActiveSupport::Concern

  ACTIVE_THRESHOLD = 60.seconds

  # True when the user has any ActionCable session that pinged us within the
  # last minute (= they have at least one Campfire tab open and connected).
  # Distinct from `online?` (per-room presence) and from `active?` (the
  # `status` enum value for the account lifecycle).
  def recently_seen?
    last_seen_at.present? && last_seen_at > ACTIVE_THRESHOLD.ago
  end

  # Skip validations / callbacks / touch — this fires on every ActionCable
  # subscribe and we want it cheap.
  def mark_seen!
    update_column(:last_seen_at, Time.current)
  end
end
