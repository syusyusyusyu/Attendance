require "test_helper"

class ClassSessionTest < ActiveSupport::TestCase
  def setup
    @teacher = User.create!(
      email: "teacher-session@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    @school_class = SchoolClass.create!(
      name: "情報I",
      teacher: @teacher,
      room: "C301",
      subject: "情報",
      semester: "後期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 3, start_time: "13:00", end_time: "14:30" }
    )
  end

  test "duration_minutes returns session length" do
    session = ClassSession.create!(
      school_class: @school_class,
      date: Date.new(2025, 1, 7),
      start_at: Time.zone.parse("2025-01-07 13:00"),
      end_at: Time.zone.parse("2025-01-07 14:30")
    )

    assert_equal 90, session.duration_minutes
  end

  test "date is unique per class" do
    ClassSession.create!(
      school_class: @school_class,
      date: Date.new(2025, 1, 7),
      start_at: Time.zone.parse("2025-01-07 13:00"),
      end_at: Time.zone.parse("2025-01-07 14:30")
    )
    duplicate = ClassSession.new(
      school_class: @school_class,
      date: Date.new(2025, 1, 7)
    )

    assert_not duplicate.valid?
  end
end
