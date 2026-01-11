require "securerandom"

module TestDataHelper
  def create_user(role:, email: nil, name: nil, student_id: nil, password: "password")
    token = SecureRandom.hex(6)
    email ||= "#{role}-#{token}@example.com"
    name ||= "#{role.capitalize} User"
    User.create!(
      email: email,
      name: name,
      role: role,
      student_id: student_id,
      password: password,
      password_confirmation: password
    )
  end

  def create_school_class(teacher:, name: "Demo Class", subject: "Demo Subject", schedule: nil)
    schedule ||= { day_of_week: 1, period: 1 }
    SchoolClass.create!(
      teacher: teacher,
      name: name,
      room: SchoolClass::ROOM_OPTIONS.first,
      subject: subject,
      semester: SchoolClass::SEMESTER_OPTIONS.first,
      year: 2026,
      capacity: 30,
      schedule: schedule
    )
  end

  def grant_permissions(role_name, *keys)
    role = Role.find_or_create_by!(name: role_name) do |record|
      record.label = role_name.capitalize
    end

    keys.flatten.each do |key|
      permission = Permission.find_or_create_by!(key: key) do |record|
        record.label = key
      end
      RolePermission.find_or_create_by!(role: role, permission: permission)
    end

    role
  end

  def sign_in_as(user, password: "password")
    post login_path, params: { email: user.email, password: password }
  end
end

