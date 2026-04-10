class AddCustomStatusToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :custom_status, :integer, default: 0
  end
end
