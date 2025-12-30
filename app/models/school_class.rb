class SchoolClass < ApplicationRecord
  belongs_to :teacher, class_name: "User"

  has_many :enrollments, dependent: :destroy
  has_many :students, through: :enrollments, source: :student
  has_many :attendance_records, dependent: :destroy
  has_many :qr_sessions, dependent: :destroy
  has_one :attendance_policy, dependent: :destroy
  has_many :class_session_overrides, dependent: :destroy
  has_many :attendance_changes, dependent: :nullify

  validates :name, :room, :subject, :semester, :year, :capacity, presence: true

  def schedule_label
    data = schedule || {}
    day_index = data["day_of_week"] || data[:day_of_week]
    start_time = data["start_time"] || data[:start_time]
    end_time = data["end_time"] || data[:end_time]

    return nil if day_index.blank? || start_time.blank? || end_time.blank?

    day_names = %w[日 月 火 水 木 金 土]
    "#{day_names[day_index.to_i]} #{start_time}-#{end_time}"
  end

  def schedule_window(date)
    data = schedule || {}
    override = class_session_overrides.find_by(date: date)

    if override&.status_canceled?
      return { canceled: true, override: override }
    end

    start_time = override&.start_time || data["start_time"] || data[:start_time]
    end_time = override&.end_time || data["end_time"] || data[:end_time]

    return nil if start_time.blank? || end_time.blank?

    start_at = Time.zone.parse("#{date} #{start_time}")
    end_at = Time.zone.parse("#{date} #{end_time}")

    return nil if start_at.blank? || end_at.blank?

    end_at += 1.day if end_at <= start_at

    {
      start_at: start_at,
      end_at: end_at,
      override: override,
      status: override&.status
    }
  end
end
