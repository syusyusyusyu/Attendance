require "test_helper"

class AttendanceFinalizerTest < ActiveSupport::TestCase
  def setup
    @teacher = User.create!(
      email: "teacher-finalize@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    @school_class = SchoolClass.create!(
      name: "理科I",
      teacher: @teacher,
      room: "D401",
      subject: "理科",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 4, start_time: "15:00", end_time: "16:30" }
    )
    AttendancePolicy.create!(
      school_class: @school_class,
      late_after_minutes: 10,
      close_after_minutes: 0,
      allow_early_checkin: true,
      max_scans_per_minute: 10,
      minimum_attendance_rate: 80,
      warning_absent_count: 3,
      warning_rate_percent: 70
    )
    @student = User.create!(
      email: "student-finalize@example.com",
      name: "Student",
      role: "student",
      student_id: "S99999",
      password: "password",
      password_confirmation: "password"
    )
    Enrollment.create!(school_class: @school_class, student: @student)
  end

  test "finalize creates absent records and locks session" do
    session = ClassSession.create!(
      school_class: @school_class,
      date: Date.new(2025, 1, 10),
      start_at: 2.hours.ago,
      end_at: 1.hour.ago
    )

    AttendanceFinalizer.new(class_session: session).finalize!(Time.current)

    record = AttendanceRecord.find_by(user: @student, school_class: @school_class, date: Date.new(2025, 1, 10))
    assert_equal "absent", record.status
    change = AttendanceChange.find_by(attendance_record: record)
    assert_equal "system", change.source
    assert_equal "出席確定(自動欠席)", change.reason
    assert session.reload.locked?
  end
end
