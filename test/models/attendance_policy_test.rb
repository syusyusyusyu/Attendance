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
      room: "4A教室",
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
    assert_includes policy.errors[:close_after_minutes], "締切は遅刻判定より後に設定してください"
  end

  test "invalid ip range is rejected" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.new(
      school_class: school_class,
      late_after_minutes: 10,
      close_after_minutes: 90,
      allowed_ip_ranges: "invalid-ip"
    )

    assert_not policy.valid?
  end

  test "early_leave? uses minimum attendance rate" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.create!(
      school_class: school_class,
      late_after_minutes: 10,
      close_after_minutes: 90,
      minimum_attendance_rate: 80
    )
    start_at = Time.zone.parse("2025-01-01 09:00")
    end_at = start_at + 100.minutes

    assert_equal 80, policy.required_attendance_minutes(100)
    assert policy.early_leave?(
      checked_in_at: start_at,
      checked_out_at: start_at + 60.minutes,
      session_start_at: start_at,
      session_end_at: end_at
    )
  end

  test "oic geofence is enforced" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.create!(
      AttendancePolicy.default_attributes.merge(
        school_class: school_class,
        require_location: false,
        geo_fence_enabled: false,
        geo_radius_m: 10,
        geo_center_lat: 0,
        geo_center_lng: 0,
        geo_postal_code: "0000000",
        geo_address: "変更前"
      )
    )

    assert policy.require_location
    assert policy.geo_fence_enabled
    assert_equal AttendancePolicy::OIC_GEO[:radius_m], policy.geo_radius_m
    assert_equal AttendancePolicy::OIC_GEO[:postal_code], policy.geo_postal_code
    assert_equal AttendancePolicy::OIC_GEO[:address], policy.geo_address
    assert_in_delta AttendancePolicy::OIC_GEO[:lat], policy.geo_center_lat, 0.00001
    assert_in_delta AttendancePolicy::OIC_GEO[:lng], policy.geo_center_lng, 0.00001
  end

  test "oic geofence defaults are applied" do
    teacher = build_teacher
    school_class = build_class(teacher)
    policy = AttendancePolicy.create!(school_class: school_class)

    assert policy.require_location
    assert policy.geo_fence_enabled
    assert_equal AttendancePolicy::OIC_GEO[:radius_m], policy.geo_radius_m
  end
end
