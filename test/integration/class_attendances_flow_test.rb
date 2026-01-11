require "test_helper"
require "rack/test"

class ClassAttendancesFlowTest < ActionDispatch::IntegrationTest
  setup do
    grant_permissions("teacher", "attendance.manage", "attendance.import", "attendance.finalize", "attendance.unlock")
    @teacher = create_user(role: "teacher")
    @admin = create_user(role: "admin")
    @student = create_user(role: "student", student_id: "S2001")
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

  test "teacher update without reason does not change" do
    sign_in_as(@teacher)

    patch attendance_path, params: {
      class_id: @school_class.id,
      date: @date.to_s,
      reason: "",
      attendance: { @student.id => "absent" }
    }

    record = AttendanceRecord.find_by(user: @student, school_class: @school_class, date: @date)
    assert_equal "present", record.status
    assert_equal 0, OperationRequest.count
  end

  test "teacher update creates operation request" do
    sign_in_as(@teacher)

    patch attendance_path, params: {
      class_id: @school_class.id,
      date: @date.to_s,
      reason: "correction",
      attendance: { @student.id => "absent" }
    }

    record = AttendanceRecord.find_by(user: @student, school_class: @school_class, date: @date)
    assert_equal "present", record.status
    assert_equal "attendance_correction", OperationRequest.last.kind
  end

  test "admin update applies change" do
    sign_in_as(@admin)

    patch attendance_path, params: {
      class_id: @school_class.id,
      date: @date.to_s,
      reason: "correction",
      attendance: { @student.id => "absent" }
    }

    record = AttendanceRecord.find_by(user: @student, school_class: @school_class, date: @date)
    assert_equal "absent", record.status
    assert AttendanceChange.exists?(attendance_record: record)
  end

  test "teacher import creates operation request" do
    sign_in_as(@teacher)

    file = Tempfile.new(["attendance", ".csv"])
    file.write("student_id,status\n")
    file.rewind

    upload = Rack::Test::UploadedFile.new(file.path, "text/csv")

    assert_difference("OperationRequest.count", 1) do
      post "/attendance/import", params: {
        class_id: @school_class.id,
        date: @date.to_s,
        csv_file: upload
      }
    end

    file.close
    file.unlink

    assert_equal "attendance_csv_import", OperationRequest.last.kind
  end

  test "admin finalize locks session" do
    class_session = ClassSession.create!(
      school_class: @school_class,
      date: @date,
      start_at: 2.hours.ago,
      end_at: 1.hour.ago
    )

    sign_in_as(@admin)

    patch attendance_finalize_path, params: { class_id: @school_class.id, date: @date.to_s }

    assert class_session.reload.locked?
  end

  test "admin unlock clears lock" do
    class_session = ClassSession.create!(
      school_class: @school_class,
      date: @date,
      start_at: 2.hours.ago,
      end_at: 1.hour.ago,
      locked_at: Time.current
    )

    sign_in_as(@admin)

    patch attendance_unlock_path, params: { class_id: @school_class.id, date: @date.to_s }

    assert_not class_session.reload.locked?
  end

  test "attendance export returns csv" do
    sign_in_as(@teacher)

    get "/attendance/export", params: { class_id: @school_class.id, start_date: @date.to_s, end_date: @date.to_s }

    assert_includes response.content_type, "text/csv"
  end
end
