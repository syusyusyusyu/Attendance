require "test_helper"

class AuthFlowTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
  end

  test "redirects to login when unauthenticated" do
    get root_path

    assert_redirected_to login_path
  end

  test "login success redirects to root" do
    user = create_user(role: "student")

    post login_path, params: { email: user.email, password: "password" }

    assert_redirected_to root_path
  end

  test "login failure returns 422" do
    user = create_user(role: "student")

    post login_path, params: { email: user.email, password: "wrong" }

    assert_response :unprocessable_entity
  end

  test "lockout after repeated failures" do
    user = create_user(role: "student")

    SessionsController::MAX_LOGIN_ATTEMPTS.times do
      post login_path, params: { email: user.email, password: "wrong" }
    end

    post login_path, params: { email: user.email, password: "wrong" }

    assert_response :too_many_requests
  end

  test "logout redirects to login" do
    user = create_user(role: "student")

    sign_in_as(user)
    delete logout_path

    assert_redirected_to login_path
  end

  test "return_to redirects after login" do
    grant_permissions("student", "qr.scan")
    student = create_user(role: "student")

    get scan_path
    assert_redirected_to login_path

    post login_path, params: { email: student.email, password: "password" }

    assert_redirected_to scan_path
  end
end

