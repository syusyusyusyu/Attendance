module OperationRequestHandlers
  class AttendanceFinalize < Base
    def call
      date = parse_date!
      class_session = class_session_from_payload(date)
      raise ArgumentError, "授業回が見つかりません" if class_session.blank?

      policy = school_class.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
      timestamp =
        if class_session.start_at.present?
          class_session.start_at + policy.close_after_minutes.minutes
        else
          Time.current
        end

      AttendanceFinalizer.new(class_session: class_session, policy: policy).finalize!(timestamp)
    end
  end
end
