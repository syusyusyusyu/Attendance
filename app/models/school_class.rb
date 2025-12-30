class SchoolClass < ApplicationRecord
  belongs_to :teacher, class_name: "User"

  has_many :enrollments, dependent: :destroy
  has_many :students, through: :enrollments, source: :student
  has_many :attendance_records, dependent: :destroy
  has_many :qr_sessions, dependent: :destroy

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
end
