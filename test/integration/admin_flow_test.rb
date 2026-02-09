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

  test "admin approves operation requests" do
    sign_in_as(@admin)

    teacher = create_user(role: "teacher")
    school_class = create_school_class(teacher: teacher)
    session = ClassSession.create!(
      school_class: school_class,
      date: Date.new(2026, 1, 5),
      start_at: 2.hours.ago,
      end_at: 1.hour.ago,
      locked_at: Time.current
    )

    request = OperationRequest.create!(
      user: teacher,
      school_class: school_class,
      kind: "attendance_unlock",
      status: "pending",
      reason: "unlock",
      payload: {
        "date" => session.date.to_s,
        "class_session_id" => session.id
      }
    )

    patch admin_operation_request_path(request), params: { decision: "approve" }

    assert_equal "approved", request.reload.status
    assert_not session.reload.locked?
  end

  test "admin rejects operation requests" do
    sign_in_as(@admin)

    teacher = create_user(role: "teacher")
    request = OperationRequest.create!(
      user: teacher,
      kind: "attendance_unlock",
      status: "pending",
      reason: "reject",
      payload: { "date" => Date.current.to_s }
    )

    patch admin_operation_request_path(request), params: { decision: "reject", decision_reason: "no" }

    assert_equal "rejected", request.reload.status
  end
end
