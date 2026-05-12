class AddEmailNotificationFields < ActiveRecord::Migration[8.2]
  def change
    add_column :users, :email_notifications_enabled, :boolean, default: true, null: false
    add_column :memberships, :last_email_notified_at, :datetime
  end
end
