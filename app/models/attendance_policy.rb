require "ipaddr"

class AttendancePolicy < ApplicationRecord
  DEFAULTS = {
    late_after_minutes: 20,
    close_after_minutes: 20,
    allow_early_checkin: true,
    max_scans_per_minute: 10,
    student_max_scans_per_minute: 6,
    minimum_attendance_rate: 80,
    warning_absent_count: 3,
    warning_rate_percent: 70,
    require_registered_device: false,
    fraud_failure_threshold: 4,
    fraud_ip_burst_threshold: 8,
    fraud_token_share_threshold: 2
  }.freeze

  belongs_to :school_class

  validates :late_after_minutes, :close_after_minutes,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_scans_per_minute,
            numericality: { only_integer: true, greater_than: 0 }
  validates :student_max_scans_per_minute,
            numericality: { only_integer: true, greater_than: 0 }
  validates :minimum_attendance_rate, :warning_rate_percent,
            numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
  validates :warning_absent_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :allow_early_checkin, :require_registered_device, inclusion: { in: [true, false] }
  validates :fraud_failure_threshold, :fraud_ip_burst_threshold, :fraud_token_share_threshold,
            numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validate :close_after_is_after_late
  validate :allowed_ip_ranges_format

  def self.default_attributes
    DEFAULTS
  end

  def attendance_rate(present:, late:, excused:, expected:)
    expected = expected.to_i
    return 0 if expected <= 0

    ((present.to_i + late.to_i + excused.to_i) * 100.0 / expected).round
  end

  def warning?(absence_total:, attendance_rate:)
    absence_total.to_i >= warning_absent_count.to_i || attendance_rate.to_i < warning_rate_percent.to_i
  end

  def warning_label(absence_total:, attendance_rate:)
    warning?(absence_total: absence_total, attendance_rate: attendance_rate) ? "要注意" : "正常"
  end

  def evaluate(scan_time:, start_at:, mode: :checkin)
    return { allowed: true, attendance_status: "present" } if start_at.blank?

    if mode.to_sym == :checkout
      return { allowed: true }
    end

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

  def required_attendance_minutes(session_length_minutes)
    return 0 if session_length_minutes.blank?
    return 0 if minimum_attendance_rate.to_i <= 0

    ((session_length_minutes.to_i * minimum_attendance_rate.to_i) / 100.0).ceil
  end

  def early_leave?(checked_in_at:, checked_out_at:, session_start_at:, session_end_at:)
    return false if checked_in_at.blank? || checked_out_at.blank?
    return false if session_start_at.blank? || session_end_at.blank?

    session_minutes = ((session_end_at - session_start_at) / 60).to_i
    required_minutes = required_attendance_minutes(session_minutes)
    duration = ((checked_out_at - checked_in_at) / 60).to_i

    duration < required_minutes
  end

  def allows_request?(ip:, user_agent:)
    ip_ok = allowed_ip_ranges_list.empty? || ip_allowed?(ip)
    ua_ok = allowed_user_agent_keywords_list.empty? || user_agent_allowed?(user_agent)

    ip_ok && ua_ok
  end

  def ip_allowed?(ip)
    address = IPAddr.new(ip)
    allowed_ip_ranges_list.any? { |range| IPAddr.new(range).include?(address) }
  rescue IPAddr::InvalidAddressError
    false
  end

  def user_agent_allowed?(user_agent)
    allowed_user_agent_keywords_list.any? do |keyword|
      user_agent.to_s.downcase.include?(keyword.downcase)
    end
  end

  def allowed_ip_ranges_list
    parse_list(allowed_ip_ranges)
  end

  def allowed_user_agent_keywords_list
    parse_list(allowed_user_agent_keywords)
  end

  private

  def close_after_is_after_late
    return if late_after_minutes.blank? || close_after_minutes.blank?

    if close_after_minutes < late_after_minutes
      errors.add(:close_after_minutes, "は遅刻判定時間以上に設定してください")
    end
  end

  def allowed_ip_ranges_format
    allowed_ip_ranges_list.each do |range|
      begin
        IPAddr.new(range)
      rescue IPAddr::InvalidAddressError
        errors.add(:allowed_ip_ranges, "に無効なIP範囲が含まれています")
      end
    end
  end

  def parse_list(value)
    value.to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?)
  end
end
