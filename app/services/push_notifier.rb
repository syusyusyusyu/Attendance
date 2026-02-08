require "web_push"

class PushNotifier
  def initialize(notification, action_url: nil)
    @notification = notification
    @user = notification.user
    @action_url = action_url
  end

  def deliver
    @user.push_subscriptions.find_each do |subscription|
      send_to_subscription(subscription)
    rescue WebPush::InvalidSubscription, WebPush::ExpiredSubscription
      subscription.destroy
    rescue WebPush::ResponseError => e
      Rails.logger.warn("Push通知の送信に失敗しました: #{e.response&.code} #{e.response&.body}")
    rescue StandardError => e
      Rails.logger.warn("Push通知の送信に失敗しました: #{e.class} #{e.message}")
    end
  end

  private

  def send_to_subscription(subscription)
    payload = {
      title: @notification.title,
      options: {
        body: @notification.body.presence || "通知があります。",
        data: {
          path: @action_url.presence || @notification.action_path.presence || "/"
        }
      }
    }

    WebPush.payload_send(
      message: JSON.generate(payload),
      endpoint: subscription.endpoint,
      p256dh: subscription.p256dh,
      auth: subscription.auth,
      vapid: vapid_config
    )
    subscription.update(last_used_at: Time.current)
  end

  def vapid_config
    {
      subject: ENV.fetch("WEBPUSH_SUBJECT", "mailto:admin@example.com"),
      public_key: ENV.fetch("WEBPUSH_PUBLIC_KEY"),
      private_key: ENV.fetch("WEBPUSH_PRIVATE_KEY")
    }
  end
end
