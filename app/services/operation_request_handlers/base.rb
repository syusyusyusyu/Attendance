module OperationRequestHandlers
  class Base
    def initialize(operation_request:, processed_by:, ip:, user_agent:)
      @operation_request = operation_request
      @processed_by = processed_by
      @ip = ip
      @user_agent = user_agent
    end

    private

    attr_reader :operation_request, :processed_by, :ip, :user_agent

    def payload
      operation_request.payload || {}
    end

    def school_class
      operation_request.school_class || raise(ArgumentError, "クラスが見つかりません")
    end

    def parse_date!
      raw = payload["date"] || payload[:date]
      raise ArgumentError, "日付が指定されていません" if raw.blank?

      Date.parse(raw.to_s)
    rescue ArgumentError
      raise ArgumentError, "日付の形式が正しくありません"
    end

    def resolve_class_session(date)
      ClassSessionResolver.new(school_class: school_class, date: date).resolve&.dig(:session)
    end

    def class_session_from_payload(date)
      class_session_id = payload["class_session_id"] || payload[:class_session_id]
      session =
        if class_session_id.present?
          ClassSession.find(class_session_id)
        else
          resolve_class_session(date)
        end

      return nil if session.blank?
      return session if session.school_class_id == school_class.id

      raise ArgumentError, "授業回が対象クラスに属していません"
    end

    def approval_reason(prefix: "承認申請")
      base = operation_request.reason.to_s.strip
      return prefix if base.empty?

      "#{prefix}: #{base}"
    end
  end
end
