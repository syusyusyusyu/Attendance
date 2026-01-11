require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email and sets defaults" do
    user = User.create!(
      email: "UPPER@EXAMPLE.COM",
      name: "User",
      role: "student",
      password: "password",
      password_confirmation: "password"
    )

    assert_equal "upper@example.com", user.email
    assert_equal true, user.settings.dig("notifications", "email")
    assert_equal false, user.settings.dig("notifications", "push")
    assert_equal false, user.settings.dig("notifications", "line")
    assert_equal false, user.settings["onboarding_seen"]
  end

  test "admin always has permission" do
    admin = create_user(role: "admin")

    assert admin.has_permission?("anything")
  end

  test "role permissions are reflected" do
    grant_permissions("teacher", "attendance.manage")
    teacher = create_user(role: "teacher")

    assert teacher.has_permission?("attendance.manage")
    assert_not teacher.has_permission?("reports.view")
  end
end

