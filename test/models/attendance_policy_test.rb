require "test_helper"

class AttendancePolicyTest < ActiveSupport::TestCase
  def build_teacher
    User.create!(
      email: "teacher-policy@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
  end

  def build_class(teacher)
    SchoolClass.create!(
      name: "数学I",
      teacher: teacher,
      room: "A101",
      subject: "数学",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 1, start_time: "09:00", end_time: "10:30" }
    )
  end

  test "present before late threshold" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.create!(school_class: school_class, late_after_minutes: 10, close_after_minutes: 90)
    start_at = Time.zone.parse("2025-01-01 09:00")

    result = policy.evaluate(scan_time: start_at + 5.minutes, start_at: start_at)

    assert result[:allowed]
    assert_equal "present", result[:attendance_status]
  end

  test "late after late threshold" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.create!(school_class: school_class, late_after_minutes: 10, close_after_minutes: 90)
    start_at = Time.zone.parse("2025-01-01 09:00")

    result = policy.evaluate(scan_time: start_at + 20.minutes, start_at: start_at)

    assert result[:allowed]
    assert_equal "late", result[:attendance_status]
  end

  test "outside window after close" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.create!(school_class: school_class, late_after_minutes: 10, close_after_minutes: 30)
    start_at = Time.zone.parse("2025-01-01 09:00")

    result = policy.evaluate(scan_time: start_at + 40.minutes, start_at: start_at)

    assert_not result[:allowed]
    assert_equal "outside_window", result[:status]
  end

  test "early scan blocked when not allowed" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.create!(
      school_class: school_class,
      late_after_minutes: 10,
      close_after_minutes: 90,
      allow_early_checkin: false
    )
    start_at = Time.zone.parse("2025-01-01 09:00")

    result = policy.evaluate(scan_time: start_at - 5.minutes, start_at: start_at)

    assert_not result[:allowed]
    assert_equal "early", result[:status]
  end

  test "close_after_minutes must be after late_after_minutes" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.new(
      school_class: school_class,
      late_after_minutes: 30,
      close_after_minutes: 10
    )

    assert_not policy.valid?
    assert_includes policy.errors[:close_after_minutes], "must be greater than or equal to late_after_minutes"
  end
end
