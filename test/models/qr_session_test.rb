require "test_helper"

class QrSessionTest < ActiveSupport::TestCase
  def setup
    @teacher = User.create!(
      email: "teacher-session@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    @school_class = SchoolClass.create!(
      name: "英語I",
      teacher: @teacher,
      room: "5B教室",
      subject: "英語",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 2, start_time: "10:00", end_time: "11:30" }
    )
  end

  test "expires_at must be after issued_at" do
    issued_at = Time.zone.parse("2025-01-01 09:00")
    qr_session = QrSession.new(
      school_class: @school_class,
      teacher: @teacher,
      attendance_date: Date.new(2025, 1, 1),
      issued_at: issued_at,
      expires_at: issued_at
    )

    assert_not qr_session.valid?
    assert_includes qr_session.errors[:expires_at], "must be after issued_at"
  end
end
