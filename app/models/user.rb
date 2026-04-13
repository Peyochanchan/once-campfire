class User < ApplicationRecord
  include Avatar, Bannable, Bot, Mentionable, Role, Transferable

  RINGTONES = %w[roli bell tada incoming mario_coin sax rimshot horn drama dangerzone secret].freeze

  has_many :memberships, dependent: :delete_all
  has_many :rooms, through: :memberships

  has_many :reachable_messages, through: :rooms, source: :messages
  has_many :messages, dependent: :destroy, foreign_key: :creator_id

  has_many :call_participants, dependent: :delete_all
  has_many :push_subscriptions, class_name: "Push::Subscription", dependent: :delete_all

  has_many :boosts, dependent: :destroy, foreign_key: :booster_id
  has_many :searches, dependent: :delete_all

  has_many :sessions, dependent: :destroy
  has_many :bans, dependent: :destroy

  has_many :sent_invitations, class_name: "Invitation", foreign_key: :invited_by_id, dependent: :destroy
  has_one  :invitation, class_name: "Invitation", foreign_key: :accepted_user_id, dependent: :nullify

  enum :status, %i[ active deactivated banned ], default: :active
  enum :custom_status, { auto: 0, away: 1, dnd: 2 }, default: :auto

  has_secure_password validations: false

  after_create_commit :grant_membership_to_open_rooms

  scope :ordered, -> { order("LOWER(name)") }
  scope :filtered_by, ->(query) { where("name like ?", "%#{query}%") }

  def online?
    memberships.connected.exists?
  end

  def in_call?
    call_participants.exists?
  end

  # Returns the effective display status combining auto-detection and manual override
  # Priority: dnd > in_call > away > online > offline
  def display_status
    return "dnd" if dnd?
    return "in_call" if in_call?
    return "away" if away?
    return "online" if online?
    "offline"
  end

  # Same as display_status but only if the viewer shares at least one room with this user
  # Prevents status disclosure across the whole instance.
  def display_status_for(viewer)
    return display_status if viewer == self
    return nil if viewer.nil?
    return display_status if shares_room_with?(viewer)
    nil
  end

  def shares_room_with?(other_user)
    rooms.where(id: other_user.rooms.select(:id)).exists?
  end

  def initials
    name.scan(/\b\w/).join
  end

  def title
    [ name, bio ].compact_blank.join(" – ")
  end

  def deactivate
    transaction do
      close_remote_connections

      memberships.without_direct_rooms.delete_all
      push_subscriptions.delete_all
      searches.delete_all
      sessions.delete_all

      update! status: :deactivated, email_address: deactived_email_address
    end
  end

  def reset_remote_connections
    close_remote_connections reconnect: true
  end

  private
    def grant_membership_to_open_rooms
      Membership.insert_all(Rooms::Open.pluck(:id).collect { |room_id| { room_id: room_id, user_id: id } })
    end

    def deactived_email_address
      email_address&.gsub(/@/, "-deactivated-#{SecureRandom.uuid}@")
    end

    def close_remote_connections(reconnect: false)
      ActionCable.server.remote_connections.where(current_user: self).disconnect reconnect: reconnect
    end
end
