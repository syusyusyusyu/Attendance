class SchoolClass < ApplicationRecord
  belongs_to :teacher, class_name: "User"

  SEMESTER_OPTIONS = %w[前期 後期].freeze
  ROOM_OPTIONS = [
    "2C教室",
    "3A教室",
    "3B教室",
    "3C教室",
    "4A教室",
    "4B教室",
    "4C教室",
    "4D教室",
    "5A教室",
    "5B教室",
    "5C教室",
    "5D教室",
    "6A教室",
    "6B教室",
    "6C教室",
    "6D教室",
    "7A教室",
    "7B教室",
    "7C教室",
    "7D教室",
    "8A教室",
    "8B教室",
    "8C教室",
    "8D教室",
    "9D-1教室",
    "9D-2教室"
  ].freeze
  PERIOD_TIMES = {
    1 => { start: "09:10", end: "10:40" },
    2 => { start: "10:50", end: "12:20" },
    3 => { start: "13:10", end: "14:40" },
    4 => { start: "14:50", end: "16:20" },
    5 => { start: "16:30", end: "18:00" }
  }.freeze
  DAY_NAMES = %w[日 月 火 水 木 金 土].freeze

  has_many :enrollments, dependent: :destroy
  has_many :students, through: :enrollments, source: :student
  has_many :attendance_records, dependent: :destroy
  has_many :qr_sessions, dependent: :destroy
  has_many :qr_scan_events, dependent: :nullify
  has_one :attendance_policy, dependent: :destroy
  has_many :class_sessions, dependent: :destroy
  has_many :class_session_overrides, dependent: :destroy
  has_many :attendance_changes, dependent: :nullify
  has_many :attendance_requests, dependent: :nullify
  has_many :operation_requests, dependent: :nullify

  validates :name, :room, :subject, :semester, :year, :capacity, presence: true
  validates :semester, inclusion: { in: SEMESTER_OPTIONS }
  validates :room, inclusion: { in: ROOM_OPTIONS }

  def self.period_options
    PERIOD_TIMES.map do |period, times|
      ["#{period}限 #{times[:start]}-#{times[:end]}", period]
    end
  end

  def self.period_times(period)
    PERIOD_TIMES[period.to_i]
  end

  def self.period_for_times(start_time, end_time)
    PERIOD_TIMES.find { |_period, times| times[:start] == start_time && times[:end] == end_time }&.first
  end

  def schedule_label
    data = schedule || {}
    day_index = data["day_of_week"] || data[:day_of_week]
    period = data["period"] || data[:period]
    start_time = data["start_time"] || data[:start_time]
    end_time = data["end_time"] || data[:end_time]

    return nil if day_index.blank?

    if period.present?
      times = self.class.period_times(period)
      return nil if times.blank?

      return "#{DAY_NAMES[day_index.to_i]} #{period}限 #{times[:start]}-#{times[:end]}"
    end

    return nil if start_time.blank? || end_time.blank?

    "#{DAY_NAMES[day_index.to_i]} #{start_time}-#{end_time}"
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
