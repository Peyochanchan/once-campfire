class AddCustomStatusTextToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :custom_status_text,  :string, limit: 80
    add_column :users, :custom_status_emoji, :string, limit: 16
  end
end
