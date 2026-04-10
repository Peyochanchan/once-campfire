class AddPinnedAtToMessages < ActiveRecord::Migration[8.2]
  def change
    add_column :messages, :pinned_at, :datetime
  end
end
