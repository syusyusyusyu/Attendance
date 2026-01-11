require "test_helper"

class AttendanceRecordTest < ActiveSupport::TestCase
  test "requires unique user per class and date" do
    teacher = create_user(role: "teacher")
    student = create_user(role: "student")
    school_class = create_school_class(teacher: teacher)

    AttendanceRecord.create!(
      user: student,
      school_class: school_class,
      date: Date.current,
      status: "present",
      verification_method: "manual"
    )

    duplicate = AttendanceRecord.new(
      user: student,
      school_class: school_class,
      date: Date.current,
      status: "late",
      verification_method: "manual"
    )

    assert_not duplicate.valid?
  end

  test "syncs duration minutes when both timestamps exist" do
    teacher = create_user(role: "teacher")
    student = create_user(role: "student")
    school_class = create_school_class(teacher: teacher)
    start_at = Time.zone.parse("2026-01-05 09:10")

    record = AttendanceRecord.create!(
      user: student,
      school_class: school_class,
      date: Date.new(2026, 1, 5),
      status: "present",
      verification_method: "manual",
      checked_in_at: start_at,
      checked_out_at: start_at + 65.minutes
    )

    assert_equal 65, record.duration_minutes
  end

  test "status helpers use AttendanceStatus" do
    record = AttendanceRecord.new(status: "present")

    assert_equal AttendanceStatus.label("present"), record.status_label
    assert_equal "badge badge-success", record.status_badge_class
  end
end

