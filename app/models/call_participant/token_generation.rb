module CallParticipant::TokenGeneration
  extend ActiveSupport::Concern

  class_methods do
    def generate_token(room:, user:)
      token = ::LiveKit::AccessToken.new(
        api_key: Rails.configuration.x.livekit.api_key,
        api_secret: Rails.configuration.x.livekit.api_secret
      )
      token.identity = user.id.to_s
      token.name = user.name
      grant = ::LiveKit::VideoGrant.new
      grant.roomJoin = true
      grant.room = "room-#{room.id}"
      token.add_grant(grant)
      token.to_jwt
    end
  end
end
