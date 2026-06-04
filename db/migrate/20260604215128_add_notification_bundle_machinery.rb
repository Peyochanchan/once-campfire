class AddNotificationBundleMachinery < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :last_seen_at,            :datetime
    add_column :users, :last_email_notified_at, :datetime
    add_index  :users, :last_seen_at

    create_table :pending_email_notifications do |t|
      t.references :user,    null: false, foreign_key: true
      t.references :room,    null: false, foreign_key: true
      t.references :message, null: false, foreign_key: true
      t.string :kind, null: false   # mention | direct | activity

      t.timestamps
    end

    add_index :pending_email_notifications, [ :user_id, :created_at ]
  end
end
