require "test_helper"

class QrCodesControllerTest < ActionDispatch::IntegrationTest
  test "missing class id returns 422 in json" do
    admin = create_user(role: "admin")

    sign_in_as(admin)
    get generate_qr_path(format: :json)

    assert_response :unprocessable_entity
  end

  test "reissue revokes previous session" do
    admin = create_user(role: "admin")
    school_class = create_school_class(teacher: admin)
    previous = QrSession.create!(
      school_class: school_class,
      teacher: admin,
      attendance_date: Time.zone.today,
      issued_at: Time.current,
      expires_at: 5.minutes.from_now
    )

    sign_in_as(admin)
    get generate_qr_path(format: :json, class_id: school_class.id)

    assert_response :success
    assert previous.reload.revoked?
  end
end
