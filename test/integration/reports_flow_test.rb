require "test_helper"

class ReportsFlowTest < ActionDispatch::IntegrationTest
  setup do
    grant_permissions("teacher", "reports.view", "reports.export")
    @teacher = create_user(role: "teacher")
    @student = create_user(role: "student", student_id: "S4001")
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

  test "reports index renders" do
    sign_in_as(@teacher)

    get reports_path

    assert_response :success
  end

  test "export requires class selection" do
    sign_in_as(@teacher)

    get reports_path(format: :csv)

    assert_redirected_to reports_path
  end

  test "export csv returns data" do
    sign_in_as(@teacher)

    get reports_path(
      format: :csv,
      class_id: @school_class.id,
      start_date: @date.to_s,
      end_date: @date.to_s
    )

    assert_includes response.content_type, "text/csv"
  end
end
