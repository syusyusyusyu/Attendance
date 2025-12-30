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
end
