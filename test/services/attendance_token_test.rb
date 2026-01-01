require "test_helper"

class AttendanceTokenTest < ActiveSupport::TestCase
  def create_teacher
    User.create!(
      email: "teacher-token@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
  end

  def create_class(teacher)
    SchoolClass.create!(
      name: "数学I",
      teacher: teacher,
      room: "4A教室",
      subject: "数学",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 1, start_time: "09:00", end_time: "10:30" }
    )
  end

  test "generate and verify token with session" do
    teacher = create_teacher
    school_class = create_class(teacher)
    issued_at = Time.current.change(sec: 0)
    qr_session = QrSession.create!(
      school_class: school_class,
      teacher: teacher,
      attendance_date: Date.current,
      issued_at: issued_at,
      expires_at: issued_at + 5.minutes
    )

    token = AttendanceToken.generate(qr_session: qr_session)
    result = AttendanceToken.verify(token)

    assert result[:ok]
    assert_equal school_class.id, result[:class_id]
    assert_equal teacher.id, result[:teacher_id]
    assert_equal qr_session.id, result[:session_id]
    assert_equal Date.current, result[:attendance_date]
  end

  test "expired token returns error status" do
    teacher = create_teacher
    school_class = create_class(teacher)
    token = AttendanceToken.generate(
      class_id: school_class.id,
      teacher_id: teacher.id,
      attendance_date: Date.current,
      expires_at: 1.minute.ago
    )

    result = AttendanceToken.verify(token)

    assert_not result[:ok]
    assert_equal "expired", result[:status]
  end

  test "invalid token returns error status" do
    result = AttendanceToken.verify("invalid-token")

    assert_not result[:ok]
    assert_equal "invalid", result[:status]
  end
end
