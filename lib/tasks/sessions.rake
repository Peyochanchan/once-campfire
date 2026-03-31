namespace :sessions do
  desc "Mark all existing sessions as verified (run after 2FA migration)"
  task verify_existing: :environment do
    count = Session.where(verified: false, otp_code: nil).update_all(verified: true)
    puts "#{count} sessions marked as verified"
  end
end
