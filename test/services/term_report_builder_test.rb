require "test_helper"

class TermReportBuilderTest < ActiveSupport::TestCase
  test "counts missing records as absences and flags alerts" do
    teacher = User.create!(
      email: "teacher-term@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    date = Date.new(2025, 1, 6)
    school_class = SchoolClass.create!(
      name: "期末評価",
      teacher: teacher,
      room: "6C教室",
      subject: "情報",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: date.wday, start_time: "09:00", end_time: "10:00" }
    )
    AttendancePolicy.create!(
      school_class: school_class,
      warning_absent_count: 1,
      warning_rate_percent: 70
    )
    student_ok = User.create!(
      email: "student-ok@example.com",
      name: "Ok Student",
      role: "student",
      student_id: "S11111",
      password: "password",
      password_confirmation: "password"
    )
    student_ng = User.create!(
      email: "student-ng@example.com",
      name: "Ng Student",
      role: "student",
      student_id: "S22222",
      password: "password",
      password_confirmation: "password"
    )
    Enrollment.create!(school_class: school_class, student: student_ok)
    Enrollment.create!(school_class: school_class, student: student_ng)

    AttendanceRecord.create!(
      user: student_ok,
      school_class: school_class,
      date: date,
      status: "present",
      verification_method: "manual",
      timestamp: Time.current
    )

    report = TermReportBuilder.new(
      school_class: school_class,
      start_date: date,
      end_date: date
    ).build

    assert_equal 1, report[:sessions_count]
    ng_row = report[:students].find { |row| row[:student] == student_ng }
    assert_equal 1, ng_row[:missing]
    assert_equal "要注意", ng_row[:alert_label]
  end
end
