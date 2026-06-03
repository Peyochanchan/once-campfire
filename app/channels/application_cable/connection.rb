module ApplicationCable
  class Connection < ActionCable::Connection::Base
    include Authentication::SessionLookup

    identified_by :current_user

    def connect
      self.current_user = find_verified_user
    end

    private
      def find_verified_user
        session = find_session_by_cookie
        reject_unauthorized_connection unless session
        # Mirror the HTTP pipeline's freshness/state checks: an attacker with a
        # stolen cookie shouldn't be able to subscribe to channels after the
        # legitimate session has been expired, deactivated, or is awaiting OTP.
        reject_unauthorized_connection if session.pending_verification?
        reject_unauthorized_connection if session.expired?
        reject_unauthorized_connection unless session.user.active?
        session.user
      end
  end
end
