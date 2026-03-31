class AddRingtoneToUsers < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :ringtone, :string, default: "roli"
  end
end
