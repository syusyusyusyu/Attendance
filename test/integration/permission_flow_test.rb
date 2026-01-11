require "test_helper"

class PermissionFlowTest < ActionDispatch::IntegrationTest
  test "permission denied redirects to root" do
    teacher = create_user(role: "teacher")

    sign_in_as(teacher)
    get reports_path

    assert_redirected_to root_path
  end
end

