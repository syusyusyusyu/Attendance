require "application_system_test_case"
require "securerandom"

class E2eSmokeTest < ApplicationSystemTestCase
  setup do
    ensure_student_permission!("qr.scan")
    @admin = create_user(role: "admin")
    @student = create_user(role: "student")
    @school_class = SchoolClass.create!(
      teacher: @admin,
      name: "Demo Class",
      room: "2C教室",
      subject: "Demo Subject",
      semester: "前期",
      year: 2026,
      capacity: 30
    )
  end

  test "admin can open QR generation on desktop" do
    sign_in(@admin.email)
    visit generate_qr_path(class_id: @school_class.id)
    assert_selector "[data-qr-target='image']"
  end

  test "student can open QR scan on mobile" do
    page.driver.browser.manage.window.resize_to(390, 844)
    sign_in(@student.email)
    visit scan_path
    assert_selector ".scan-frame"
    assert_selector "[data-qr-scan-target='video']"
  end

  private

  def sign_in(email, password: "password")
    visit login_path
    fill_in "email", with: email
    fill_in "password", with: password
    click_button "ログイン"
    assert_text "ログインしました。"
  end

  def create_user(role:)
    token = SecureRandom.hex(6)
    User.create!(
      email: "#{role}-#{token}@example.com",
      name: "#{role.capitalize} User",
      role: role,
      password: "password",
      password_confirmation: "password"
    )
  end

  def ensure_student_permission!(key)
    role = Role.find_or_create_by!(name: "student") do |record|
      record.label = "Student"
    end
    permission = Permission.find_or_create_by!(key: key) do |record|
      record.label = key
    end
    RolePermission.find_or_create_by!(role: role, permission: permission)
  end
end
