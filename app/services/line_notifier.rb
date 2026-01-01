require "net/http"
require "json"

class LineNotifier
  API_ENDPOINT = URI("https://api.line.me/v2/bot/message/push")

  def initialize(channel_token:)
    @channel_token = channel_token
  end

  def push(user_id:, message:)
    return if user_id.blank? || message.blank?

    payload = {
      to: user_id,
      messages: [{ type: "text", text: message }]
    }

    request = Net::HTTP::Post.new(API_ENDPOINT)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{@channel_token}"
    request.body = JSON.generate(payload)

    Net::HTTP.start(API_ENDPOINT.host, API_ENDPOINT.port, use_ssl: true) do |http|
      response = http.request(request)
      unless response.is_a?(Net::HTTPSuccess)
        Rails.logger.warn("LINE通知の送信に失敗しました: #{response.code} #{response.body}")
      end
    end
  rescue StandardError => e
    Rails.logger.warn("LINE通知の送信に失敗しました: #{e.class} #{e.message}")
  end
end
