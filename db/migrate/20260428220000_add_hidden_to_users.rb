class AddHiddenToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :hidden, :boolean, default: false, null: false
    add_index :users, :hidden
  end
end
