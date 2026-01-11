require "test_helper"

class NotificationsFlowTest < ActionDispatch::IntegrationTest
  setup do
    grant_permissions("student", "notifications.view")
    @student = create_user(role: "student")
    Notification.create!(
      user: @student,
      kind: "info",
      title: "Notice",
      body: "Body",
      action_path: "/"
    )
  end

  test "notifications index renders" do
    sign_in_as(@student)

    get notifications_path

    assert_response :success
  end

  test "mark all sets read_at" do
    sign_in_as(@student)

    assert @student.notifications.unread.exists?

    patch "/notifications/mark-all"

    assert_not @student.notifications.unread.exists?
    assert @student.notifications.reload.all? { |note| note.read_at.present? }
  end
end
