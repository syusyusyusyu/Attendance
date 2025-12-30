require "test_helper"

class ClassSessionOverrideTest < ActiveSupport::TestCase
  def setup
    @teacher = User.create!(
      email: "teacher-override@example.com",
      name: "Teacher",
      role: "teacher",
      password: "password",
      password_confirmation: "password"
    )
    @class = SchoolClass.create!(
      name: "理科I",
      teacher: @teacher,
      room: "C301",
      subject: "理科",
      semester: "前期",
      year: 2024,
      capacity: 40,
      schedule: { day_of_week: 3, start_time: "13:00", end_time: "14:30" }
    )
  end

  test "requires start_time and end_time together" do
    override = ClassSessionOverride.new(
      school_class: @class,
      date: Date.new(2025, 1, 10),
      start_time: "10:00"
    )

    assert_not override.valid?
  end
end
