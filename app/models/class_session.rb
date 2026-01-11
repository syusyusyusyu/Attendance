class ClassSession < ApplicationRecord
  belongs_to :school_class
  has_many :attendance_records, dependent: :nullify
  has_many :attendance_requests, dependent: :nullify

  enum :status, {
    regular: "regular",
    makeup: "makeup",
    canceled: "canceled"
  }, prefix: true

  validates :date, presence: true
  validates :date, uniqueness: { scope: :school_class_id }

  def locked?
    locked_at.present?
  end

  def duration_minutes
    return nil if start_at.blank? || end_at.blank?

    ((end_at - start_at) / 60).to_i
  end

  def status_label
    {
      "regular" => "通常",
      "makeup" => "補講",
      "canceled" => "休講"
    }[status] || status
  end

  def status_badge_class
    base = "inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium border"
    {
      "regular" => "#{base} bg-blue-50 text-blue-700 border-blue-100",
      "makeup" => "#{base} bg-yellow-50 text-yellow-700 border-yellow-100",
      "canceled" => "#{base} bg-red-50 text-red-700 border-red-100"
    }[status] || "#{base} bg-gray-50 text-gray-700 border-gray-100"
  end

  def lock_label
    locked? ? "確定済" : "受付中"
  end

  def lock_badge_class
    base = "inline-flex items-center px-2 py-0.5 rounded-md text-xs font-medium border"
    locked? ? "#{base} bg-gray-100 text-gray-600 border-gray-200" : "#{base} bg-green-50 text-green-700 border-green-100"
  end
end
