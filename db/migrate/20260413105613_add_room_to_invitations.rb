class AddRoomToInvitations < ActiveRecord::Migration[8.2]
  def change
    add_reference :invitations, :room, null: true, foreign_key: true
  end
end
