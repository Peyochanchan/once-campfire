class Account < ApplicationRecord
  include Joinable

  has_one_attached :logo
  has_settings restrict_room_creation_to_administrators: :boolean, max_invites: 10, name: "hero"
end
