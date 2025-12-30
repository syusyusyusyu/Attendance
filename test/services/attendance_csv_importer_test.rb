require "test_helper"

class AttendanceCsvImporterTest < ActiveSupport::TestCase
  def setup
    @teacher = User.create!(
      email: "teacher-import@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    @class = SchoolClass.create!(
      name: "数学I",
      teacher: @teacher,
      room: "A101",
      subject: "数学",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 1, start_time: "09:00", end_time: "10:30" }
    )
    @student_one = User.create!(
      email: "student-one@example.com",
      name: "Student One",
      role: "student",
      student_id: "S12345",
      password: "password",
      password_confirmation: "password"
    )
    @student_two = User.create!(
      email: "student-two@example.com",
      name: "Student Two",
      role: "student",
      student_id: "S54321",
      password: "password",
      password_confirmation: "password"
    )
    Enrollment.create!(school_class: @class, student: @student_one)
    Enrollment.create!(school_class: @class, student: @student_two)
  end

  test "imports attendance records and skips missing status rows" do
    csv_text = <<~CSV
      日付,学生ID,出席状況,備考
      2025-01-01,S12345,出席,特になし
      2025-01-01,S54321,遅刻,
      2025-01-01,S99999,出席,
      2025-01-01,S12345,未入力,
    CSV

    result = AttendanceCsvImporter.new(
      teacher: @teacher,
      school_class: @class,
      csv_text: csv_text
    ).import

    assert_equal 2, result[:created]
    assert_equal 0, result[:updated]
    assert_equal 1, result[:skipped]
    assert_equal 1, result[:errors].size
    assert AttendanceRecord.exists?(user: @student_one, school_class: @class, date: Date.new(2025, 1, 1))
  end

  test "accepts english status values" do
    csv_text = <<~CSV
      date,student_id,status
      2025-01-02,S12345,late
    CSV

    result = AttendanceCsvImporter.new(
      teacher: @teacher,
      school_class: @class,
      csv_text: csv_text
    ).import

    record = AttendanceRecord.find_by(user: @student_one, school_class: @class, date: Date.new(2025, 1, 2))

    assert_equal 1, result[:created]
    assert_equal "late", record.status
  end

  test "imports check in and out times with early leave" do
    csv_text = <<~CSV
      日付,学生ID,出席状況,入室時刻,退室時刻,滞在分
      2025-01-03,S12345,早退,09:00,09:30,30
    CSV

    result = AttendanceCsvImporter.new(
      teacher: @teacher,
      school_class: @class,
      csv_text: csv_text
    ).import

    record = AttendanceRecord.find_by(user: @student_one, school_class: @class, date: Date.new(2025, 1, 3))

    assert_equal 1, result[:created]
    assert_equal "early_leave", record.status
    assert_equal 30, record.duration_minutes
    assert_equal Time.zone.parse("2025-01-03 09:00"), record.checked_in_at
    assert_equal Time.zone.parse("2025-01-03 09:30"), record.checked_out_at
  end
end
