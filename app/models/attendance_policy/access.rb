class AttendancePolicy
  class Access
    def initialize(policy)
      @policy = policy
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
      parse_list(@policy.allowed_ip_ranges)
    end

    def allowed_user_agent_keywords_list
      parse_list(@policy.allowed_user_agent_keywords)
    end

    private

    def parse_list(value)
      value.to_s.split(/[\s,]+/).map(&:strip).reject(&:blank?)
    end
  end
end
