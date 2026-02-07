require "test_helper"

class PushNotifierTest < ActiveSupport::TestCase
  setup do
    @user = create_user(role: "student")
    @notification = Notification.create!(
      user: @user,
      kind: "info",
      title: "テスト通知",
      body: "Push通知のテスト",
      action_path: "/notifications"
    )
    @subscription = PushSubscription.create!(
      user: @user,
      endpoint: "https://push.example.com/sub/#{SecureRandom.hex(8)}",
      p256dh: "test-p256dh-key",
      auth: "test-auth-key"
    )
  end

  test "deliver sends push to each subscription" do
    sent_endpoints = []

    with_env(
      "WEBPUSH_PUBLIC_KEY" => "BPubKey123",
      "WEBPUSH_PRIVATE_KEY" => "PrivKey456"
    ) do
      Webpush.stub(:payload_send, ->(message:, endpoint:, p256dh:, auth:, vapid:) {
        sent_endpoints << endpoint
      }) do
        PushNotifier.new(@notification, action_url: "https://app.example.com/notifications").deliver
      end
    end

    assert_includes sent_endpoints, @subscription.endpoint
  end

  test "deliver updates last_used_at on successful send" do
    assert_nil @subscription.last_used_at

    with_env(
      "WEBPUSH_PUBLIC_KEY" => "BPubKey123",
      "WEBPUSH_PRIVATE_KEY" => "PrivKey456"
    ) do
      Webpush.stub(:payload_send, ->(**_) { true }) do
        PushNotifier.new(@notification).deliver
      end
    end

    @subscription.reload
    assert_not_nil @subscription.last_used_at
  end

  test "deliver removes expired subscription" do
    with_env(
      "WEBPUSH_PUBLIC_KEY" => "BPubKey123",
      "WEBPUSH_PRIVATE_KEY" => "PrivKey456"
    ) do
      Webpush.stub(:payload_send, ->(**_) {
        error = Webpush::ExpiredSubscription.new(nil, "https://push.example.com")
        raise error
      }) do
        assert_difference -> { PushSubscription.count }, -1 do
          PushNotifier.new(@notification).deliver
        end
      end
    end
  end

  test "deliver removes invalid subscription" do
    with_env(
      "WEBPUSH_PUBLIC_KEY" => "BPubKey123",
      "WEBPUSH_PRIVATE_KEY" => "PrivKey456"
    ) do
      Webpush.stub(:payload_send, ->(**_) {
        error = Webpush::InvalidSubscription.new(nil, "https://push.example.com")
        raise error
      }) do
        assert_difference -> { PushSubscription.count }, -1 do
          PushNotifier.new(@notification).deliver
        end
      end
    end
  end

  test "deliver logs warning on response error without raising" do
    with_env(
      "WEBPUSH_PUBLIC_KEY" => "BPubKey123",
      "WEBPUSH_PRIVATE_KEY" => "PrivKey456"
    ) do
      Webpush.stub(:payload_send, ->(**_) {
        raise Webpush::ResponseError.new(nil, "https://push.example.com")
      }) do
        assert_nothing_raised do
          PushNotifier.new(@notification).deliver
        end
      end
    end

    assert PushSubscription.exists?(@subscription.id)
  end

  test "deliver includes correct payload structure" do
    captured_payload = nil

    with_env(
      "WEBPUSH_PUBLIC_KEY" => "BPubKey123",
      "WEBPUSH_PRIVATE_KEY" => "PrivKey456"
    ) do
      Webpush.stub(:payload_send, ->(message:, **_) {
        captured_payload = JSON.parse(message)
      }) do
        PushNotifier.new(@notification, action_url: "https://app.example.com/notifications").deliver
      end
    end

    assert_equal "テスト通知", captured_payload["title"]
    assert_equal "Push通知のテスト", captured_payload["options"]["body"]
    assert_equal "https://app.example.com/notifications", captured_payload["options"]["data"]["path"]
  end

  test "deliver uses VAPID config from environment" do
    captured_vapid = nil

    with_env(
      "WEBPUSH_PUBLIC_KEY" => "my-public-key",
      "WEBPUSH_PRIVATE_KEY" => "my-private-key",
      "WEBPUSH_SUBJECT" => "mailto:admin@school.jp"
    ) do
      Webpush.stub(:payload_send, ->(vapid:, **_) {
        captured_vapid = vapid
      }) do
        PushNotifier.new(@notification).deliver
      end
    end

    assert_equal "my-public-key", captured_vapid[:public_key]
    assert_equal "my-private-key", captured_vapid[:private_key]
    assert_equal "mailto:admin@school.jp", captured_vapid[:subject]
  end

  private

  def with_env(overrides, &block)
    old_values = {}
    overrides.each do |key, value|
      old_values[key] = ENV[key]
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
    yield
  ensure
    old_values.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end
end
