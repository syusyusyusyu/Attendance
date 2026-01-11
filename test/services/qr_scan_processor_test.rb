require "test_helper"

class QrScanProcessorTest < ActiveSupport::TestCase
  class NullLimiter
    def user_limited?(limit:)
      false
    end

    def class_limited?(limit:)
      false
    end
  end

  class SequenceLimiter
    def initialize(user_results: [], class_results: [])
      @user_results = user_results
      @class_results = class_results
    end

    def user_limited?(limit:)
      @user_results.shift || false
    end

    def class_limited?(limit:)
      @class_results.shift || false
    end
  end

  setup do
    @teacher = create_user(role: "teacher")
    @student = create_user(role: "student")
    @date = Date.new(2026, 1, 5)
    @school_class = create_school_class(
      teacher: @teacher,
      schedule: { day_of_week: @date.wday, period: 1 }
    )
    Enrollment.create!(school_class: @school_class, student: @student)
    @policy = AttendancePolicy.create!(
      school_class: @school_class,
      late_after_minutes: 10,
      close_after_minutes: 20,
      allow_early_checkin: true,
      max_scans_per_minute: 10,
      student_max_scans_per_minute: 6,
      minimum_attendance_rate: 80,
      warning_absent_count: 3,
      warning_rate_percent: 70
    )
    @issued_at = Time.zone.parse("2026-01-05 09:10")
    @qr_session = QrSession.create!(
      school_class: @school_class,
      teacher: @teacher,
      attendance_date: @date,
      issued_at: @issued_at,
      expires_at: @issued_at + 5.minutes
    )
  end

  test "blank token logs invalid" do
    result = with_limiter(NullLimiter.new) do
      QrScanProcessor.new(
        user: @student,
        token: nil,
        ip: "203.0.113.10",
        user_agent: "Browser",
        device: nil,
        now: @issued_at
      ).call
    end

    assert_equal :alert, result.flash
    assert_equal "invalid", QrScanEvent.last.status
  end

  test "invalid token logs invalid" do
    result = call_processor(token_result: { ok: false, error: "invalid", status: "invalid" })

    assert_equal :alert, result.flash
    assert_equal "invalid", QrScanEvent.last.status
  end

  test "missing session logs session_missing" do
    result = call_processor(token_result: ok_payload.merge(session_id: 999_999))

    assert_equal :alert, result.flash
    assert_equal "session_missing", QrScanEvent.last.status
  end

  test "revoked session logs revoked" do
    @qr_session.update!(revoked_at: Time.current)

    result = call_processor

    assert_equal :alert, result.flash
    assert_equal "revoked", QrScanEvent.last.status
  end

  test "expired session logs expired" do
    @qr_session.update!(expires_at: @issued_at - 1.minute)

    result = call_processor

    assert_equal :alert, result.flash
    assert_equal "expired", QrScanEvent.last.status
  end

  test "wrong date logs wrong_date" do
    result = call_processor(token_result: ok_payload.merge(attendance_date: @date + 1.day))

    assert_equal :alert, result.flash
    assert_equal "wrong_date", QrScanEvent.last.status
  end

  test "not enrolled logs not_enrolled" do
    other_student = create_user(role: "student")

    result = call_processor(user: other_student)

    assert_equal :alert, result.flash
    assert_equal "not_enrolled", QrScanEvent.last.status
  end

  test "rate limited logs rate_limited" do
    limiter = SequenceLimiter.new(user_results: [true])

    result = with_limiter(limiter) do
      QrScanProcessor.new(
        user: @student,
        token: "token",
        ip: "203.0.113.10",
        user_agent: "Browser",
        device: nil,
        now: @issued_at
      ).call
    end

    assert_equal :alert, result.flash
    assert_equal "rate_limited", QrScanEvent.last.status
  end

  test "ip blocked logs ip_blocked" do
    @policy.update!(allowed_ip_ranges: "10.0.0.0/8")

    result = call_processor(ip: "192.168.0.10")

    assert_equal :alert, result.flash
    assert_equal "ip_blocked", QrScanEvent.last.status
  end

  test "device blocked logs device_blocked when user agent denied" do
    @policy.update!(allowed_user_agent_keywords: "Allowed")

    result = call_processor(user_agent: "Unknown")

    assert_equal :alert, result.flash
    assert_equal "device_blocked", QrScanEvent.last.status
  end

  test "registered device requirement blocks unapproved" do
    @policy.update!(require_registered_device: true)

    result = call_processor(device: nil)

    assert_equal :alert, result.flash
    assert_equal "device_blocked", QrScanEvent.last.status
  end

  test "no schedule logs no_schedule" do
    @school_class.update!(schedule: { day_of_week: (@date.wday + 1) % 7, period: 1 })

    result = call_processor

    assert_equal :alert, result.flash
    assert_equal "no_schedule", QrScanEvent.last.status
  end

  test "canceled session logs class_canceled" do
    ClassSessionOverride.create!(school_class: @school_class, date: @date, status: "canceled")

    result = call_processor

    assert_equal :alert, result.flash
    assert_equal "class_canceled", QrScanEvent.last.status
  end

  test "locked session logs session_locked" do
    ClassSession.create!(
      school_class: @school_class,
      date: @date,
      start_at: @issued_at,
      end_at: @issued_at + 90.minutes,
      locked_at: Time.current
    )
    @qr_session.update!(issued_at: @issued_at, expires_at: @issued_at + 5.minutes)

    result = call_processor

    assert_equal :alert, result.flash
    assert_equal "session_locked", QrScanEvent.last.status
  end

  test "manual override logs manual_override" do
    AttendanceRecord.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      status: "present",
      verification_method: "manual",
      timestamp: @issued_at,
      modified_by: @teacher
    )

    result = call_processor

    assert_equal :alert, result.flash
    assert_equal "manual_override", QrScanEvent.last.status
  end

  test "successful scan records attendance" do
    result = call_processor

    assert_equal :notice, result.flash
    record = AttendanceRecord.find_by(user: @student, school_class: @school_class, date: @date)
    assert_equal "present", record.status
    assert_equal "success", QrScanEvent.last.status
  end

  test "checkout marks early_leave when stay is short" do
    AttendanceRecord.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      status: "present",
      verification_method: "qrcode",
      timestamp: @issued_at,
      checked_in_at: @issued_at
    )

    result = call_processor(now: @issued_at + 30.minutes)

    assert_equal :notice, result.flash
    record = AttendanceRecord.find_by(user: @student, school_class: @school_class, date: @date)
    assert record.checked_out_at
    assert_equal "early_leave", record.status
    assert_equal "checkout", QrScanEvent.last.status
  end

  test "checkout duplicate logs checkout_duplicate" do
    AttendanceRecord.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      status: "present",
      verification_method: "qrcode",
      timestamp: @issued_at,
      checked_in_at: @issued_at,
      checked_out_at: @issued_at + 60.minutes
    )

    result = call_processor(now: @issued_at + 70.minutes)

    assert_equal :notice, result.flash
    assert_equal "checkout_duplicate", QrScanEvent.last.status
  end

  private

  def ok_payload
    {
      ok: true,
      session_id: @qr_session.id,
      class_id: @school_class.id,
      attendance_date: @date,
      expires_at: @qr_session.expires_at
    }
  end

  def call_processor(token_result: ok_payload, token: "token", user: @student, ip: "203.0.113.10", user_agent: "Browser", device: nil, now: @issued_at + 1.minute)
    with_limiter(NullLimiter.new) do
      AttendanceToken.stub(:verify, token_result) do
        QrScanProcessor.new(
          user: user,
          token: token,
          ip: ip,
          user_agent: user_agent,
          device: device,
          now: now
        ).call
      end
    end
  end

  def with_limiter(limiter)
    QrScanRateLimiter.stub(:new, limiter) do
      yield
    end
  end
end

