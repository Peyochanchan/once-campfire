module CallParticipant::TokenGeneration
  extend ActiveSupport::Concern

  class_methods do
    def generate_token(room:, user:, avatar_url: nil)
      token = ::LiveKit::AccessToken.new(
        api_key: Rails.configuration.x.livekit.api_key,
        api_secret: Rails.configuration.x.livekit.api_secret
      )
      token.identity = user.id.to_s
      token.name = user.name
      token.metadata = { avatar_url: avatar_url }.to_json if avatar_url
      grant = ::LiveKit::VideoGrant.new
      grant.roomJoin = true
      grant.room = "room-#{room.id}"
      token.add_grant(grant)
      token.to_jwt
    end
  end
end
