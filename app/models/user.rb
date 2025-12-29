class User < ApplicationRecord
  has_secure_password

  enum :role, {
    student: "student",
    teacher: "teacher",
    admin: "admin"
  }, prefix: true

  has_many :taught_classes,
           class_name: "SchoolClass",
           foreign_key: :teacher_id,
           dependent: :destroy
  has_many :enrollments, foreign_key: :student_id, dependent: :destroy
  has_many :enrolled_classes, through: :enrollments, source: :school_class
  has_many :attendance_records, dependent: :destroy
  has_many :attendance_updates,
           class_name: "AttendanceRecord",
           foreign_key: :modified_by_id,
           dependent: :nullify

  validates :email, :name, :role, presence: true
  validates :email, uniqueness: true
  validates :student_id, uniqueness: true, allow_nil: true

  before_validation :normalize_email

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
