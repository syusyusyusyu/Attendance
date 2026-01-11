class AttendancePolicy
  class Warnings
    def initialize(policy)
      @policy = policy
    end

    def attendance_rate(present:, late:, excused:, expected:)
      expected = expected.to_i
      return 0 if expected <= 0

      ((present.to_i + late.to_i + excused.to_i) * 100.0 / expected).round
    end

    def warning?(absence_total:, attendance_rate:)
      absence_total.to_i >= warning_absent_count || attendance_rate.to_i < warning_rate_percent
    end

    def warning_label(absence_total:, attendance_rate:)
      warning?(absence_total: absence_total, attendance_rate: attendance_rate) ? "要注意" : "正常"
    end

    def warning_absent_count
      @policy.warning_absent_count.to_i
    end

    def warning_rate_percent
      @policy.warning_rate_percent.to_i
    end
  end
end
