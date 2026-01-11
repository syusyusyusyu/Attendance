require "application_system_test_case"

class QrGenerationUiTest < ApplicationSystemTestCase
  setup do
    @admin = create_user(role: "admin")
    @school_class = create_school_class(teacher: @admin)
  end

  test "shows guidance when class not selected" do
    sign_in(@admin.email)
    visit generate_qr_path

    assert_text "クラスを選択するとQRコードが生成されます。"
  end

  test "shows qr data when class selected" do
    sign_in(@admin.email)
    visit generate_qr_path(class_id: @school_class.id)

    assert_selector "[data-qr-target='image']"
    assert_selector "[data-qr-target='timeLeft']"
    assert_selector "button[data-action='qr#download']"
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

