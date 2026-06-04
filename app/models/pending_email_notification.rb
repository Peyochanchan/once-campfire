class PendingEmailNotification < ApplicationRecord
  belongs_to :user
  belongs_to :room
  belongs_to :message

  KINDS = %w[ mention direct activity ].freeze
  validates :kind, presence: true, inclusion: { in: KINDS }

  scope :for_user, ->(user_id) { where(user_id: user_id) }
end
