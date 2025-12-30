class SchoolClass < ApplicationRecord
  belongs_to :teacher, class_name: "User"

  has_many :enrollments, dependent: :destroy
  has_many :students, through: :enrollments, source: :student
  has_many :attendance_records, dependent: :destroy
  has_many :qr_sessions, dependent: :destroy
  has_one :attendance_policy, dependent: :destroy
  has_many :class_sessions, dependent: :destroy
  has_many :class_session_overrides, dependent: :destroy
  has_many :attendance_changes, dependent: :nullify
  has_many :attendance_requests, dependent: :nullify

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
    result = ClassSessionResolver.new(school_class: self, date: date).resolve
    return nil unless result

    session = result.fetch(:session)

    if session.status_canceled?
      return { canceled: true, override: result[:override], class_session: session }
    end

    return nil if session.start_at.blank? || session.end_at.blank?

    {
      start_at: session.start_at,
      end_at: session.end_at,
      override: result[:override],
      status: session.status,
      class_session: session
    }
  end
end
