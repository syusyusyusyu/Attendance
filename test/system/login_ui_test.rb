require "application_system_test_case"

class LoginUiTest < ApplicationSystemTestCase
  test "role toggle and password visibility" do
    visit login_path

    role_input = find("input[name='role']", visible: false)
    assert_equal "student", role_input.value

    find("button[data-login-target='roleTeacher']").click
    assert_equal "teacher", role_input.value
    assert_selector "button[data-login-target='roleTeacher'].bg-google-blue"

    password_input = find("input[name='password']")
    assert_equal "password", password_input[:type]

    find("button[data-action='login#togglePassword']").click
    assert_equal "text", find("input[name='password']")[:type]
  end

  test "demo login fills fields" do
    visit login_path

    find("button[data-login-role-param='student']").click
    assert_equal "student@example.com", find("input[name='email']").value
    assert_equal "password", find("input[name='password']").value

    find("button[data-login-role-param='teacher']").click
    assert_equal "teacher@example.com", find("input[name='email']").value
  end

  test "first login shows onboarding" do
    student = User.create!(
      email: "onboarding-student@example.com",
      name: "Student",
      role: "student",
      password: "password",
      password_confirmation: "password"
    )

    visit login_path
    fill_in "email", with: student.email
    fill_in "password", with: "password"
    click_button "ログイン"

    assert_text "初回ガイド"
  end
end

