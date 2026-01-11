module OperationRequestHandlers
  class AttendanceUnlock < Base
    def call
      date = parse_date!
      class_session = class_session_from_payload(date)
      raise ArgumentError, "授業回が見つかりません" if class_session.blank?

      return unless class_session.locked?

      class_session.update!(locked_at: nil)
    end
  end
end
