require "test_helper"

class SchoolClassTest < ActiveSupport::TestCase
  test "period helpers resolve times" do
    times = SchoolClass.period_times(1)

    assert_equal "09:10", times[:start]
    assert_equal "10:40", times[:end]
    assert_equal 1, SchoolClass.period_for_times(times[:start], times[:end])
  end

  test "schedule_label uses period when provided" do
    teacher = create_user(role: "teacher")
    school_class = create_school_class(
      teacher: teacher,
      schedule: { day_of_week: 1, period: 1 }
    )

    expected_day = SchoolClass::DAY_NAMES[1]
    times = SchoolClass.period_times(1)
    expected = "#{expected_day} 1限 #{times[:start]}-#{times[:end]}"

    assert_equal expected, school_class.schedule_label
  end

  test "schedule_window returns session when day matches" do
    teacher = create_user(role: "teacher")
    date = Date.new(2026, 1, 5)
    school_class = create_school_class(
      teacher: teacher,
      schedule: { day_of_week: date.wday, period: 1 }
    )

    window = school_class.schedule_window(date)

    assert window
    assert window[:start_at]
    assert window[:end_at]
    assert window[:class_session]
  end

  test "schedule_window returns nil when day mismatches" do
    teacher = create_user(role: "teacher")
    date = Date.new(2026, 1, 5)
    school_class = create_school_class(
      teacher: teacher,
      schedule: { day_of_week: (date.wday + 1) % 7, period: 1 }
    )

    assert_nil school_class.schedule_window(date)
  end
end

