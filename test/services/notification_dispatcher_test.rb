require "test_helper"

class NotificationDispatcherTest < ActiveSupport::TestCase
  setup do
    @user = create_user(role: "student")
    @notification = Notification.create!(
      user: @user,
      kind: "info",
      title: "テスト通知",
      body: "テスト本文",
      action_path: "/notifications"
    )
  end

  test "delivers email when email is enabled and SENDGRID_API_KEY is set" do
    @user.update!(settings: { "notifications" => { "email" => true, "line" => false, "push" => false } })

    with_env("SENDGRID_API_KEY" => "test-key") do
      dispatcher = NotificationDispatcher.new(@notification)

      mail_mock = Minitest::Mock.new
      mail_mock.expect(:deliver_now, true)

      NotificationMailer.stub(:alert, ->(_notif, **_opts) { mail_mock }) do
        dispatcher.deliver
      end

      mail_mock.verify
    end
  end

  test "skips email when user preference is disabled" do
    @user.update!(settings: { "notifications" => { "email" => false, "line" => false, "push" => false } })

    with_env("SENDGRID_API_KEY" => "test-key") do
      dispatcher = NotificationDispatcher.new(@notification)

      NotificationMailer.stub(:alert, ->(*) { raise "should not be called" }) do
        dispatcher.deliver
      end
    end
  end

  test "skips email when SENDGRID_API_KEY is absent" do
    @user.update!(settings: { "notifications" => { "email" => true, "line" => false, "push" => false } })

    with_env("SENDGRID_API_KEY" => nil) do
      dispatcher = NotificationDispatcher.new(@notification)

      NotificationMailer.stub(:alert, ->(*) { raise "should not be called" }) do
        dispatcher.deliver
      end
    end
  end

  test "delivers LINE when line is enabled and credentials are set" do
    @user.update!(settings: {
      "notifications" => { "email" => false, "line" => true, "push" => false },
      "line_user_id" => "U1234567890"
    })

    with_env("LINE_CHANNEL_ACCESS_TOKEN" => "test-token") do
      dispatcher = NotificationDispatcher.new(@notification.reload)

      push_called = false
      fake_notifier = Object.new
      fake_notifier.define_singleton_method(:push) do |user_id:, message:|
        push_called = true
      end

      LineNotifier.stub(:new, ->(**_opts) { fake_notifier }) do
        dispatcher.deliver
      end

      assert push_called, "LINE push should have been called"
    end
  end

  test "skips LINE when line_user_id is blank" do
    @user.update!(settings: {
      "notifications" => { "email" => false, "line" => true, "push" => false }
    })

    with_env("LINE_CHANNEL_ACCESS_TOKEN" => "test-token") do
      dispatcher = NotificationDispatcher.new(@notification.reload)

      LineNotifier.stub(:new, ->(**_opts) { raise "should not be called" }) do
        dispatcher.deliver
      end
    end
  end

  test "delivers push when push is enabled and subscriptions exist" do
    @user.update!(settings: { "notifications" => { "email" => false, "line" => false, "push" => true } })
    PushSubscription.create!(
      user: @user,
      endpoint: "https://push.example.com/sub1",
      p256dh: "test-p256dh",
      auth: "test-auth"
    )

    with_env("WEBPUSH_PUBLIC_KEY" => "pub-key", "WEBPUSH_PRIVATE_KEY" => "priv-key") do
      dispatcher = NotificationDispatcher.new(@notification.reload)

      deliver_called = false
      fake_push = Object.new
      fake_push.define_singleton_method(:deliver) { deliver_called = true }

      PushNotifier.stub(:new, ->(_notif, **_opts) { fake_push }) do
        dispatcher.deliver
      end

      assert deliver_called, "Push deliver should have been called"
    end
  end

  test "skips push when no subscriptions exist" do
    @user.update!(settings: { "notifications" => { "email" => false, "line" => false, "push" => true } })

    with_env("WEBPUSH_PUBLIC_KEY" => "pub-key", "WEBPUSH_PRIVATE_KEY" => "priv-key") do
      dispatcher = NotificationDispatcher.new(@notification.reload)

      PushNotifier.stub(:new, ->(*) { raise "should not be called" }) do
        dispatcher.deliver
      end
    end
  end

  test "action_url returns absolute URL when APP_HOST is set" do
    with_env("APP_HOST" => "https://app.example.com") do
      dispatcher = NotificationDispatcher.new(@notification)
      assert_equal "https://app.example.com/notifications", dispatcher.action_url
    end
  end

  test "action_url returns relative path when no host is configured" do
    with_env("APP_HOST" => nil, "RENDER_EXTERNAL_HOSTNAME" => nil) do
      dispatcher = NotificationDispatcher.new(@notification)
      assert_equal "/notifications", dispatcher.action_url
    end
  end

  test "action_url returns nil when action_path is blank" do
    @notification.update!(action_path: nil)
    dispatcher = NotificationDispatcher.new(@notification)
    assert_nil dispatcher.action_url
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
