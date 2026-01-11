require "test_helper"

class ProfileFlowTest < ActionDispatch::IntegrationTest
  setup do
    grant_permissions("student", "profile.manage")
    @student = create_user(role: "student")
  end

  test "profile update changes name" do
    sign_in_as(@student)

    patch profile_path, params: { user: { name: "Updated Name" } }

    assert_equal "Updated Name", @student.reload.name
  end

  test "notification preferences are saved" do
    sign_in_as(@student)

    patch profile_path, params: {
      notifications: {
        email: "1",
        push: "0",
        line: "1",
        line_user_id: "line-123"
      }
    }

    prefs = @student.reload.notification_preferences
    assert_equal true, prefs["email"]
    assert_equal false, prefs["push"]
    assert_equal true, prefs["line"]
    assert_equal "line-123", @student.settings["line_user_id"]
  end
end
