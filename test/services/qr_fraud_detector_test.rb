require "test_helper"

class QrFraudDetectorTest < ActiveSupport::TestCase
  test "notifies teacher when access is blocked" do
    teacher = User.create!(
      email: "teacher-fraud@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    school_class = SchoolClass.create!(
      name: "監査演習",
      teacher: teacher,
      room: "5B教室",
      subject: "情報",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 2, start_time: "13:00", end_time: "14:30" }
    )
    AttendancePolicy.create!(school_class: school_class)

    event = QrScanEvent.create!(
      status: "ip_blocked",
      token_digest: "token",
      school_class: school_class,
      ip: "10.0.0.1",
      scanned_at: Time.current
    )

    assert_difference -> { Notification.count }, 1 do
      QrFraudDetector.new(event: event).call
    end

    notification = Notification.order(created_at: :desc).first
    assert_equal teacher, notification.user
    assert_match "不正スキャン", notification.title
  end
end
