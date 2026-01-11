require "test_helper"

class AttendanceHistoryFlowTest < ActionDispatch::IntegrationTest
  setup do
    grant_permissions("student", "history.view", "history.export")
    @student = create_user(role: "student", student_id: "S3001")
    @teacher = create_user(role: "teacher")
    @date = Date.new(2026, 1, 5)
    @school_class = create_school_class(
      teacher: @teacher,
      schedule: { day_of_week: @date.wday, period: 1 }
    )
    Enrollment.create!(school_class: @school_class, student: @student)
    AttendanceRecord.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      status: "present",
      verification_method: "manual",
      timestamp: Time.current
    )
  end

  test "history show works" do
    sign_in_as(@student)

    get history_path(date: @date.to_s)

    assert_response :success
  end

  test "history export csv" do
    sign_in_as(@student)

    get attendance_history_export_path(format: :csv, start_date: @date.to_s, end_date: @date.to_s)

    assert_includes response.content_type, "text/csv"
  end

  test "history rejects invalid date" do
    sign_in_as(@student)

    get history_path(date: "invalid")

    assert_redirected_to history_path
  end
end
