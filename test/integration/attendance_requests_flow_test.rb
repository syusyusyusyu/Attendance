require "test_helper"

class AttendanceRequestsFlowTest < ActionDispatch::IntegrationTest
  setup do
    grant_permissions("student", "attendance.request.view", "attendance.request.create")
    grant_permissions("teacher", "attendance.request.view", "attendance.request.approve")
    @teacher = create_user(role: "teacher")
    @student = create_user(role: "student", student_id: "S1001")
    @date = Date.new(2026, 1, 5)
    @school_class = create_school_class(
      teacher: @teacher,
      schedule: { day_of_week: @date.wday, period: 1 }
    )
    Enrollment.create!(school_class: @school_class, student: @student)
  end

  test "student request requires reason" do
    sign_in_as(@student)

    assert_no_difference("AttendanceRequest.count") do
      post attendance_requests_path, params: {
        attendance_request: {
          school_class_id: @school_class.id,
          date: @date.to_s,
          request_type: "absent",
          reason: ""
        }
      }
    end

    assert_redirected_to attendance_requests_path
  end

  test "student can create request" do
    sign_in_as(@student)

    assert_difference("AttendanceRequest.count", 1) do
      post attendance_requests_path, params: {
        attendance_request: {
          school_class_id: @school_class.id,
          date: @date.to_s,
          request_type: "absent",
          reason: "sick"
        }
      }
    end

    assert_equal 1, Notification.where(user: @teacher).count
  end

  test "duplicate pending request is rejected" do
    AttendanceRequest.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      request_type: "absent",
      reason: "sick",
      submitted_at: Time.current,
      status: "pending"
    )

    sign_in_as(@student)

    assert_no_difference("AttendanceRequest.count") do
      post attendance_requests_path, params: {
        attendance_request: {
          school_class_id: @school_class.id,
          date: @date.to_s,
          request_type: "absent",
          reason: "repeat"
        }
      }
    end
  end

  test "teacher approves request and updates attendance" do
    request = AttendanceRequest.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      request_type: "late",
      reason: "train",
      submitted_at: Time.current,
      status: "pending"
    )

    sign_in_as(@teacher)

    patch attendance_request_path(request), params: {
      attendance_request: { status: "approved" }
    }

    assert_equal "approved", request.reload.status
    record = AttendanceRecord.find_by(user: @student, school_class: @school_class, date: @date)
    assert_equal "late", record.status
  end

  test "teacher can bulk approve requests" do
    request_a = AttendanceRequest.create!(
      user: @student,
      school_class: @school_class,
      date: @date,
      request_type: "absent",
      reason: "sick",
      submitted_at: Time.current,
      status: "pending"
    )
    request_b = AttendanceRequest.create!(
      user: @student,
      school_class: @school_class,
      date: @date + 1.day,
      request_type: "excused",
      reason: "official",
      submitted_at: Time.current,
      status: "pending"
    )

    sign_in_as(@teacher)

    patch bulk_update_attendance_requests_path, params: {
      request_ids: [request_a.id, request_b.id],
      status: "approved"
    }

    assert_equal "approved", request_a.reload.status
    assert_equal "approved", request_b.reload.status
  end
end

