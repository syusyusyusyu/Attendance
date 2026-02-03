class User < ApplicationRecord
  has_secure_password

  enum :role, {
    student: "student",
    teacher: "teacher",
    admin: "admin"
  }

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
  has_many :attendance_change_records,
           class_name: "AttendanceChange",
           foreign_key: :user_id,
           dependent: :nullify
  has_many :attendance_requests, dependent: :destroy
  has_many :processed_attendance_requests,
           class_name: "AttendanceRequest",
           foreign_key: :processed_by_id,
           dependent: :nullify
  has_many :operation_requests, dependent: :destroy
  has_many :processed_operation_requests,
           class_name: "OperationRequest",
           foreign_key: :processed_by_id,
           dependent: :nullify
  has_many :audit_saved_searches, dependent: :destroy
  has_many :qr_sessions,
           foreign_key: :teacher_id,
           dependent: :destroy
  has_many :qr_scan_events, dependent: :nullify
  has_many :attendance_changes,
           foreign_key: :modified_by_id,
           dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  validates :email, :name, :role, presence: true
  validates :email, uniqueness: true
  validates :student_id, uniqueness: true, allow_nil: true

  def staff?
    teacher? || admin?
  end

  def manageable_classes
    admin? ? SchoolClass.all : taught_classes
  end

  before_validation :normalize_email
  before_validation :ensure_settings_defaults

  def role_record
    Role.find_by(name: role)
  end

  def permissions
    role_record ? role_record.permissions.pluck(:key) : []
  end

  def has_permission?(permission_key)
    return true if admin?

    permissions.include?(permission_key.to_s)
  end

  def notification_preferences
    defaults = { "email" => true, "push" => false, "line" => false }
    settings.fetch("notifications", {}).reverse_merge(defaults)
  end

  def line_user_id
    settings["line_user_id"].to_s.strip.presence
  end

  # デモアカウントかどうか判定
  DEMO_EMAILS = %w[admin@example.com teacher@example.com student@example.com].freeze

  def demo_account?
    DEMO_EMAILS.include?(email)
  end

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end

  def ensure_settings_defaults
    self.settings ||= {}
    settings["notifications"] ||= {}
    settings["notifications"]["email"] = true if settings["notifications"]["email"].nil?
    settings["notifications"]["push"] = false if settings["notifications"]["push"].nil?
    settings["notifications"]["line"] = false if settings["notifications"]["line"].nil?
    settings["onboarding_seen"] = false if settings["onboarding_seen"].nil?
  end
end
