class AttendancePolicy
  class RateLimit
    def initialize(policy)
      @policy = policy
    end

    def class_limit
      @policy.max_scans_per_minute.to_i
    end

    def student_limit
      @policy.student_max_scans_per_minute.to_i
    end
  end
end
