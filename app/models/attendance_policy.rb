class AttendancePolicy < ApplicationRecord
  DEFAULTS = {
    late_after_minutes: 10,
    close_after_minutes: 90,
    allow_early_checkin: true
  }.freeze

  belongs_to :school_class

  validates :late_after_minutes, :close_after_minutes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :allow_early_checkin, inclusion: { in: [true, false] }
  validate :close_after_is_after_late

  def self.default_attributes
    DEFAULTS
  end

  def evaluate(scan_time:, start_at:)
    return { allowed: true, attendance_status: "present" } if start_at.blank?

    if !allow_early_checkin && scan_time < start_at
      return {
        allowed: false,
        status: "early",
        message: "授業開始前のため出席登録できません。"
      }
    end

    late_at = start_at + late_after_minutes.minutes
    close_at = start_at + close_after_minutes.minutes

    if scan_time > close_at
      return {
        allowed: false,
        status: "outside_window",
        message: "出席登録時間外です。"
      }
    end

    attendance_status = scan_time > late_at ? "late" : "present"

    {
      allowed: true,
      attendance_status: attendance_status
    }
  end

  private

  def close_after_is_after_late
    return if late_after_minutes.blank? || close_after_minutes.blank?

    if close_after_minutes < late_after_minutes
      errors.add(:close_after_minutes, "must be greater than or equal to late_after_minutes")
    end
  end
end
