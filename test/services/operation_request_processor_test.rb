require "test_helper"

class OperationRequestProcessorTest < ActiveSupport::TestCase
  test "approves attendance correction and creates logs" do
    admin = User.create!(
      email: "admin-ops@example.com",
      name: "ŠÇ—Ò",
      role: "admin",
      password: "password",
      password_confirmation: "password"
    )
    teacher = User.create!(
      email: "teacher-ops@example.com",
      name: "’S“–‹³ˆõ",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    student = User.create!(
      email: "student-ops@example.com",
      name: "óu¶",
      role: "student",
      student_id: "S9999",
      password: "password",
      password_confirmation: "password"
    )

    school_class = SchoolClass.create!(
      name: "‰^—p‰‰K",
      teacher: teacher,
      room: "4B‹³º",
      subject: "î•ñ",
      semester: "ŒãŠú",
      year: 2024,
      capacity: 30,
      schedule: { day_of_week: 1, start_time: "09:10", end_time: "10:40" }
    )
    Enrollment.create!(school_class: school_class, student: student)

    date = Date.parse("2025-01-06")
    AttendanceRecord.create!(
      user: student,
      school_class: school_class,
      date: date,
      status: "absent",
      verification_method: "manual",
      timestamp: Time.current
    )

    request = OperationRequest.create!(
      user: teacher,
      school_class: school_class,
      kind: "attendance_correction",
      status: "pending",
      payload: {
        "date" => date.to_s,
        "changes" => [{ "user_id" => student.id, "status" => "present" }],
        "reason" => "‘Ì’²•s—Ç"
      }
    )

    processor = OperationRequestProcessor.new(
      operation_request: request,
      processed_by: admin,
      ip: "127.0.0.1",
      user_agent: "test"
    )

    assert_difference -> { AttendanceChange.count }, 1 do
      assert_difference -> { Notification.count }, 1 do
        processor.approve!
      end
    end

    record = AttendanceRecord.find_by(user: student, school_class: school_class, date: date)
    assert_equal "present", record.status

    change = AttendanceChange.order(created_at: :desc).first
    assert_equal "³”F\¿: ‘Ì’²•s—Ç", change.reason
  end
end
