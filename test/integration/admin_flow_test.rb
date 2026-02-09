require "test_helper"

class AdminFlowTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create_user(role: "admin")
  end

  test "admin dashboard renders" do
    sign_in_as(@admin)

    get admin_path

    assert_response :success
  end

  test "admin can manage users" do
    sign_in_as(@admin)

    assert_difference("User.count", 1) do
      post admin_users_path, params: {
        user: {
          name: "New User",
          email: "new-user@example.com",
          role: "student",
          password: "password",
          password_confirmation: "password"
        }
      }
    end

    user = User.find_by(email: "new-user@example.com")
    patch admin_user_path(user), params: { user: { name: "Updated" } }

    assert_equal "Updated", user.reload.name

    assert_difference("User.count", -1) do
      delete admin_user_path(user)
    end
  end

  test "admin can update roles" do
    sign_in_as(@admin)

    role = Role.create!(name: "teacher", label: "Teacher")
    permission = Permission.create!(key: "reports.view", label: "reports.view")

    patch admin_role_path(role), params: {
      role: { label: "Teacher Updated" },
      permission_ids: [permission.id]
    }

    assert_equal "Teacher Updated", role.reload.label
    assert_equal [permission.id], role.permission_ids
  end

end
