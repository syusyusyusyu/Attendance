module OperationRequestHandlers
  class AttendanceCorrection < Base
    def call
      date = parse_date!
      changes = Array(payload["changes"] || payload[:changes])
      raise ArgumentError, "修正内容がありません" if changes.blank?

      class_session = resolve_class_session(date)

      changes.each do |change|
        user_id = change["user_id"] || change[:user_id]
        status = change["status"] || change[:status]
        next if user_id.blank? || status.blank?

        record = AttendanceRecord.find_or_initialize_by(
          user_id: user_id,
          school_class: school_class,
          date: date
        )
        previous_status = record.status

        record.status = status
        record.verification_method = "manual"
        record.timestamp ||= Time.current
        record.modified_by = processed_by
        record.modified_at = Time.current
        record.class_session ||= class_session if class_session
        record.save!

        next if previous_status.nil? || previous_status == record.status

        AttendanceChange.create!(
          attendance_record: record,
          user: record.user,
          school_class: school_class,
          date: date,
          previous_status: previous_status,
          new_status: record.status,
          reason: approval_reason,
          modified_by: processed_by,
          source: "manual",
          ip: ip,
          user_agent: user_agent,
          changed_at: Time.current
        )

        Notification.create!(
          user: record.user,
          kind: "info",
          title: "出席状況が更新されました",
          body: "#{school_class.name} (#{date.strftime('%Y-%m-%d')}) の出席が更新されました。",
          action_path: Rails.application.routes.url_helpers.history_path(date: date)
        )
      end
    end
  end
end
