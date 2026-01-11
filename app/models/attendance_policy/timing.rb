class AttendancePolicy
  class Timing
    def initialize(policy)
      @policy = policy
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

      if scan_time > close_at(start_at)
        return {
          allowed: false,
          status: "outside_window",
          message: "出席登録の受付時間を過ぎています。"
        }
      end

      attendance_status = scan_time > late_at(start_at) ? "late" : "present"

      {
        allowed: true,
        attendance_status: attendance_status
      }
    end

    def late_at(start_at)
      start_at + late_after_minutes.minutes
    end

    def close_at(start_at)
      start_at + close_after_minutes.minutes
    end

    def late_after_minutes
      @policy.late_after_minutes
    end

    def close_after_minutes
      @policy.close_after_minutes
    end

    def allow_early_checkin
      @policy.allow_early_checkin
    end
  end
end
