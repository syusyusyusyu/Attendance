require "test_helper"
require "digest"

class LogsFlowTest < ActionDispatch::IntegrationTest
  setup do
    grant_permissions("teacher", "scan.logs.view", "attendance.logs.view")
    @teacher = create_user(role: "teacher")
    @student = create_user(role: "student", student_id: "S5001")
    @date = Date.new(2026, 1, 5)
    @school_class = create_school_class(
      teacher: @teacher,
      schedule: { day_of_week: @date.wday, period: 1 }
    )
    Enrollment.create!(school_class: @school_class, student: @student)

    @scan_event = QrScanEvent.create!(
      status: "success",
      token_digest: Digest::SHA256.hexdigest("token"),
      user: @student,
      school_class: @school_class,
      scanned_at: Time.current,
      attendance_status: "present"
    )

    @record = AttendanceRecord.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      status: "present",
      verification_method: "manual",
      timestamp: Time.current
    )
    AttendanceChange.create!(
      attendance_record: @record,
      user: @student,
      school_class: @school_class,
      date: @date,
      previous_status: "absent",
      new_status: "present",
      reason: "manual",
      modified_by: @teacher,
      source: "manual",
      ip: "203.0.113.5",
      user_agent: "Browser",
      changed_at: Time.current
    )
  end

  test "scan logs index and csv" do
    sign_in_as(@teacher)

    get scan_logs_path, params: { class_id: @school_class.id, status: "success" }
    assert_response :success

    get scan_logs_path(format: :csv, class_id: @school_class.id)
    assert_includes response.content_type, "text/csv"
  end

  test "attendance change logs index, save search, and csv" do
    sign_in_as(@teacher)

    get attendance_logs_path
    assert_response :success

    assert_difference("AuditSavedSearch.count", 1) do
      get attendance_logs_path, params: {
        save_search_name: "recent",
        class_id: @school_class.id,
        source: "manual"
      }
    end

    get attendance_logs_path(format: :csv, class_id: @school_class.id)
    assert_includes response.content_type, "text/csv"
  end
end
