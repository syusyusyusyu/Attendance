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

  def timing_policy
    @timing_policy ||= AttendancePolicy::Timing.new(self)
  end

  def warning_policy
    @warning_policy ||= AttendancePolicy::Warnings.new(self)
  end

  def attendance_rate_policy
    @attendance_rate_policy ||= AttendancePolicy::AttendanceRate.new(self)
  end

  def access_policy
    @access_policy ||= AttendancePolicy::Access.new(self)
  end

  def rate_limit_policy
    @rate_limit_policy ||= AttendancePolicy::RateLimit.new(self)
  end

  def fraud_policy
    @fraud_policy ||= AttendancePolicy::Fraud.new(self)
  end

  def attendance_rate(present:, late:, excused:, expected:)
    warning_policy.attendance_rate(present: present, late: late, excused: excused, expected: expected)
  end

  def warning?(absence_total:, attendance_rate:)
    warning_policy.warning?(absence_total: absence_total, attendance_rate: attendance_rate)
  end

  def warning_label(absence_total:, attendance_rate:)
    warning_policy.warning_label(absence_total: absence_total, attendance_rate: attendance_rate)
  end

  def evaluate(scan_time:, start_at:, mode: :checkin)
    timing_policy.evaluate(scan_time: scan_time, start_at: start_at, mode: mode)
  end

  def required_attendance_minutes(session_length_minutes)
    attendance_rate_policy.required_attendance_minutes(session_length_minutes)
  end

  def early_leave?(checked_in_at:, checked_out_at:, session_start_at:, session_end_at:)
    attendance_rate_policy.early_leave?(
      checked_in_at: checked_in_at,
      checked_out_at: checked_out_at,
      session_start_at: session_start_at,
      session_end_at: session_end_at
    )
  end

  def allows_request?(ip:, user_agent:)
    access_policy.allows_request?(ip: ip, user_agent: user_agent)
  end

  def ip_allowed?(ip)
    access_policy.ip_allowed?(ip)
  end

  def user_agent_allowed?(user_agent)
    access_policy.user_agent_allowed?(user_agent)
  end

  def allowed_ip_ranges_list
    access_policy.allowed_ip_ranges_list
  end

  def allowed_user_agent_keywords_list
    access_policy.allowed_user_agent_keywords_list
  end

  private

  def close_after_is_after_late
    return if late_after_minutes.blank? || close_after_minutes.blank?

    if close_after_minutes < late_after_minutes
      errors.add(:close_after_minutes, "締切は遅刻判定より後に設定してください")
    end
  end

  def allowed_ip_ranges_format
    access_policy.allowed_ip_ranges_list.each do |range|
      begin
        IPAddr.new(range)
      rescue IPAddr::InvalidAddressError
        errors.add(:allowed_ip_ranges, "許可IPの形式が正しくありません")
      end
    end
  end
end
