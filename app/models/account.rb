class Account < ApplicationRecord
  include Joinable

  has_one_attached :logo
  has_json :settings, schema: { restrict_room_creation_to_administrators: false }, delegate: true
end
