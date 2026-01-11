class AttendancePolicy
  class AttendanceRate
    def initialize(policy)
      @policy = policy
    end

    def required_attendance_minutes(session_length_minutes)
      return 0 if session_length_minutes.blank?
      return 0 if minimum_attendance_rate <= 0

      ((session_length_minutes.to_i * minimum_attendance_rate) / 100.0).ceil
    end

    def early_leave?(checked_in_at:, checked_out_at:, session_start_at:, session_end_at:)
      return false if checked_in_at.blank? || checked_out_at.blank?
      return false if session_start_at.blank? || session_end_at.blank?

      session_minutes = ((session_end_at - session_start_at) / 60).to_i
      required_minutes = required_attendance_minutes(session_minutes)
      duration = ((checked_out_at - checked_in_at) / 60).to_i

      duration < required_minutes
    end

    def minimum_attendance_rate
      @policy.minimum_attendance_rate.to_i
    end
  end
end
