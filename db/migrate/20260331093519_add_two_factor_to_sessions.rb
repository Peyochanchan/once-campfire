class AddTwoFactorToSessions < ActiveRecord::Migration[8.2]
  def change
    add_column :sessions, :otp_code, :string
    add_column :sessions, :otp_sent_at, :datetime
    add_column :sessions, :verified, :boolean, default: false, null: false
  end
end
