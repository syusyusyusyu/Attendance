require "application_system_test_case"

class QrScanUiTest < ApplicationSystemTestCase
  setup do
    grant_permissions("student", "qr.scan")
    @student = create_user(role: "student")
  end

  test "scan page shows camera area and manual toggle" do
    sign_in(@student.email)
    visit scan_path

    assert_selector ".scan-frame"
    assert_selector "[data-qr-scan-target='video']"
    assert_selector "[data-qr-scan-target='manual'].hidden"

    click_button "手入力"
    assert_selector "[data-qr-scan-target='manual']:not(.hidden)"
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

