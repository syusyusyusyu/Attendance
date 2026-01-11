require "test_helper"

class EnrollmentTest < ActiveSupport::TestCase
  test "student cannot enroll twice in same class" do
    teacher = create_user(role: "teacher")
    student = create_user(role: "student")
    school_class = create_school_class(teacher: teacher)

    Enrollment.create!(school_class: school_class, student: student)
    duplicate = Enrollment.new(school_class: school_class, student: student)

    assert_not duplicate.valid?
  end
end

