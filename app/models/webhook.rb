require "net/http"
require "uri"
require "restricted_http/private_network_guard"

class Webhook < ApplicationRecord
  ENDPOINT_TIMEOUT = 7.seconds
  MAX_BODY_SIZE = 5.megabytes
  ALLOWED_SCHEMES = %w[http https].freeze

  ResponseData = Data.define(:code, :content_type, :body)

  belongs_to :user

  def deliver(message)
    response = post(payload(message))
    return response unless response

    if text = extract_text_from(response)
      receive_text_reply_to(message.room, text: text)
    elsif attachment = extract_attachment_from(response)
      receive_attachment_reply_to(message.room, attachment: attachment)
    end

    response
  rescue Net::OpenTimeout, Net::ReadTimeout
    receive_text_reply_to message.room, text: "Failed to respond within #{ENDPOINT_TIMEOUT} seconds"
  rescue RestrictedHTTP::Violation => e
    Rails.logger.warn "[Webhook] refused for bot #{user.id}: #{e.message}"
    receive_text_reply_to message.room, text: "Webhook URL refused: blocked by security policy."
  end

  private
    def post(payload)
      validate_scheme!
      ip = RestrictedHTTP::PrivateNetworkGuard.resolve(uri.host)
      response_data = nil

      Net::HTTP.start(uri.host, uri.port, ipaddr: ip,
                      use_ssl: uri.scheme == "https",
                      open_timeout: ENDPOINT_TIMEOUT,
                      read_timeout: ENDPOINT_TIMEOUT) do |http|
        request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        request.body = payload
        http.request(request) do |response|
          body = read_body_bounded(response)
          response_data = ResponseData.new(code: response.code, content_type: response.content_type, body: body)
        end
      end

      response_data
    end

    # Read response body chunked, capping at MAX_BODY_SIZE so a malicious
    # bot (or any compromised endpoint) cannot exhaust the worker memory or
    # S3 storage budget by returning gigabytes.
    def read_body_bounded(response)
      buf = StringIO.new
      response.read_body do |chunk|
        return nil if buf.size + chunk.bytesize > MAX_BODY_SIZE
        buf.write(chunk)
      end
      buf.string
    end

    def validate_scheme!
      unless ALLOWED_SCHEMES.include?(uri.scheme)
        raise RestrictedHTTP::Violation, "Disallowed scheme: #{uri.scheme.inspect}"
      end
    end

    def uri
      @uri ||= URI(url)
    end

    def payload(message)
      {
        user:    { id: message.creator.id, name: message.creator.name },
        room:    { id: message.room.id, name: message.room.name, path: room_bot_messages_path(message) },
        message: { id: message.id, body: { html: message.body.body, plain: without_recipient_mentions(message.plain_text_body) }, path: message_path(message) }
      }.to_json
    end

    def message_path(message)
      Rails.application.routes.url_helpers.room_at_message_path(message.room, message)
    end

    def room_bot_messages_path(message)
      Rails.application.routes.url_helpers.room_bot_messages_path(message.room, user.bot_key)
    end

    def extract_text_from(response)
      return nil unless response.body
      return nil unless response.code == "200" && response.content_type.in?(%w[ text/html text/plain ])
      String.new(response.body).force_encoding("UTF-8")
    end

    def receive_text_reply_to(room, text:)
      room.messages.create!(body: text, creator: user).broadcast_create
    end

    def extract_attachment_from(response)
      return nil unless response.body && response.content_type
      mime_type = Mime::Type.lookup(response.content_type)
      return nil unless mime_type
      ActiveStorage::Blob.create_and_upload! \
        io: StringIO.new(response.body), filename: "attachment.#{mime_type.symbol}", content_type: mime_type.to_s
    end

    def receive_attachment_reply_to(room, attachment:)
      room.messages.create_with_attachment!(attachment: attachment, creator: user).broadcast_create
    end

    def without_recipient_mentions(body)
      body \
        .gsub(user.attachable_plain_text_representation(nil), "") # Remove mentions of the recipient user
        .gsub(/\A\p{Space}+|\p{Space}+\z/, "") # Remove leading and trailing whitespace uncluding unicode spaces
    end
end
