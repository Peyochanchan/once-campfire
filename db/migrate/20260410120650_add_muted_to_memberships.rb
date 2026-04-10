class AddMutedToMemberships < ActiveRecord::Migration[8.2]
  def change
    add_column :memberships, :muted, :boolean, default: false, null: false
  end
end
