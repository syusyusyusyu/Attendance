class AttendancePolicy
  class Fraud
    def initialize(policy)
      @policy = policy
    end

    def failure_threshold
      @policy.fraud_failure_threshold.to_i
    end

    def ip_burst_threshold
      @policy.fraud_ip_burst_threshold.to_i
    end

    def token_share_threshold
      @policy.fraud_token_share_threshold.to_i
    end
  end
end
