# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
teacher = User.find_or_initialize_by(email: "teacher@example.com")
teacher.assign_attributes(
  name: "鈴木先生",
  role: "teacher",
  password: "password",
  password_confirmation: "password"
)
teacher.save!

student = User.find_or_initialize_by(email: "student@example.com")
student.assign_attributes(
  name: "山田太郎",
  role: "student",
  student_id: "S12345",
  password: "password",
  password_confirmation: "password"
)
student.save!

class_one = SchoolClass.find_or_create_by!(name: "数学I", teacher: teacher) do |klass|
  klass.room = "A101"
  klass.subject = "数学"
  klass.semester = "前期"
  klass.year = 2024
  klass.capacity = 40
  klass.schedule = { day_of_week: 1, start_time: "09:00", end_time: "10:30", frequency: "weekly" }
end

Enrollment.find_or_create_by!(school_class: class_one, student: student)
