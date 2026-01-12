require "application_system_test_case"

class DashboardUiTest < ApplicationSystemTestCase
  test "student dashboard shows scan card" do
    student = create_user(role: "student")

    sign_in(student.email)

    assert_text "QRスキャン"
  end

  test "teacher dashboard shows attendance card" do
    teacher = create_user(role: "teacher")
    create_school_class(teacher: teacher)

    sign_in(teacher.email)

    assert_text "出席確認"
    assert_text "今日の授業"
  end

  private

  def sign_in(email, password: "password")
    visit login_path
    fill_in "email", with: email
    fill_in "password", with: password
    click_button "ログイン"
    assert_current_path root_path, ignore_query: true
  end
end
