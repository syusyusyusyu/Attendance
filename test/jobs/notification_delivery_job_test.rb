require "test_helper"

class NotificationDeliveryJobTest < ActiveSupport::TestCase
  setup do
    @user = create_user(role: "student")
    @user.update!(settings: { "notifications" => { "email" => false, "line" => false, "push" => false } })
    @notification = Notification.create!(
      user: @user,
      kind: "info",
      title: "ジョブテスト通知",
      body: "テスト"
    )
  end

  test "perform calls NotificationDispatcher#deliver" do
    delivered = false

    fake_dispatcher = Object.new
    fake_dispatcher.define_singleton_method(:deliver) { delivered = true }

    NotificationDispatcher.stub(:new, ->(_notif) { fake_dispatcher }) do
      NotificationDeliveryJob.perform_now(@notification.id)
    end

    assert delivered, "Dispatcher#deliver should have been called"
  end

  test "perform silently returns when notification does not exist" do
    assert_nothing_raised do
      NotificationDeliveryJob.perform_now(-1)
    end
  end

  test "perform silently returns when notification was deleted" do
    notification_id = @notification.id
    @notification.destroy!

    assert_nothing_raised do
      NotificationDeliveryJob.perform_now(notification_id)
    end
  end

  test "job is enqueued when notification is created" do
    @user.update!(settings: { "notifications" => { "email" => false, "line" => false, "push" => false } })

    assert_enqueued_with(job: NotificationDeliveryJob) do
      Notification.create!(
        user: @user,
        kind: "success",
        title: "キュー確認テスト"
      )
    end
  end
end
