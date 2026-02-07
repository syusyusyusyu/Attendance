require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  setup do
    @user = create_user(role: "student", email: "student-mailer@example.com")
    @notification = Notification.create!(
      user: @user,
      kind: "info",
      title: "出席状況が更新されました",
      body: "2限の出席が「出席」に変更されました。",
      action_path: "/history"
    )
  end

  test "alert sets correct subject and recipient" do
    mail = NotificationMailer.alert(@notification, action_url: "https://app.example.com/history")

    assert_equal ["student-mailer@example.com"], mail.to
    assert_equal "出席状況が更新されました", mail.subject
  end

  test "alert html body contains title and body" do
    mail = NotificationMailer.alert(@notification, action_url: "https://app.example.com/history")

    assert_match "出席状況が更新されました", mail.html_part.body.to_s
    assert_match "2限の出席が「出席」に変更されました", mail.html_part.body.to_s
  end

  test "alert html body contains action link when url is present" do
    mail = NotificationMailer.alert(@notification, action_url: "https://app.example.com/history")

    assert_match "https://app.example.com/history", mail.html_part.body.to_s
    assert_match "詳細を見る", mail.html_part.body.to_s
  end

  test "alert text body contains notification content" do
    mail = NotificationMailer.alert(@notification, action_url: "https://app.example.com/history")

    assert_match "出席状況が更新されました", mail.text_part.body.to_s
    assert_match "2限の出席が「出席」に変更されました", mail.text_part.body.to_s
  end

  test "alert without action_url omits link" do
    mail = NotificationMailer.alert(@notification, action_url: nil)

    refute_match "詳細を見る", mail.html_part.body.to_s
  end

  test "alert with blank body shows default message" do
    @notification.update!(body: nil)
    mail = NotificationMailer.alert(@notification)

    assert_match "通知があります", mail.html_part.body.to_s
  end
end
