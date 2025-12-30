require "test_helper"

class AttendanceRequestTest < ActiveSupport::TestCase
  def setup
    @teacher = User.create!(
      email: "teacher-request@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    @school_class = SchoolClass.create!(
      name: "英語I",
      teacher: @teacher,
      room: "B201",
      subject: "英語",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 2, start_time: "10:00", end_time: "11:30" }
    )
    @student = User.create!(
      email: "student-request@example.com",
      name: "Student",
      role: "student",
      student_id: "S77777",
      password: "password",
      password_confirmation: "password"
    )
    Enrollment.create!(school_class: @school_class, student: @student)
  end

  test "requires reason and submitted_at" do
    request = AttendanceRequest.new(
      user: @student,
      school_class: @school_class,
      date: Date.new(2025, 1, 5),
      request_type: "absent",
      submitted_at: nil
    )

    assert_not request.valid?
    assert_includes request.errors[:reason], "can't be blank"
    assert_includes request.errors[:submitted_at], "can't be blank"
  end

  test "accepts pending status by default" do
    request = AttendanceRequest.create!(
      user: @student,
      school_class: @school_class,
      date: Date.new(2025, 1, 5),
      request_type: "late",
      reason: "体調不良",
      submitted_at: Time.current
    )

    assert request.status_pending?
  end
end
