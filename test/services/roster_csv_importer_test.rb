require "test_helper"

class RosterCsvImporterTest < ActiveSupport::TestCase
  def setup
    @teacher = User.create!(
      email: "teacher-roster@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    @class = SchoolClass.create!(
      name: "英語I",
      teacher: @teacher,
      room: "5B教室",
      subject: "英語",
      semester: "後期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 2, start_time: "10:00", end_time: "11:30" }
    )
  end

  test "imports roster and enrolls students" do
    csv_text = <<~CSV
      学生ID,氏名,メール,パスワード
      S10001,山田花子,hanako@example.com,pass1234
    CSV

    result = RosterCsvImporter.new(
      teacher: @teacher,
      school_class: @class,
      csv_text: csv_text
    ).import

    student = User.find_by(email: "hanako@example.com")

    assert_equal 1, result[:created]
    assert_equal 1, result[:enrolled]
    assert_equal "student", student.role
    assert Enrollment.exists?(school_class: @class, student: student)
  end
end
