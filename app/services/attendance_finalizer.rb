class AttendanceFinalizer
  def self.finalize_all!
    ClassSession.where(locked_at: nil).find_each do |session|
      new(class_session: session).finalize_if_due!
    end
  end

  def initialize(class_session:, policy: nil)
    @class_session = class_session
    @school_class = class_session.school_class
    @policy = policy || @school_class.attendance_policy || @school_class.create_attendance_policy(AttendancePolicy.default_attributes)
  end

  def finalize_if_due!
    return false if @class_session.locked? || @class_session.status_canceled?
    return false if @class_session.start_at.blank?

    close_at = @class_session.start_at + @policy.close_after_minutes.minutes
    return false if Time.current < close_at

    finalize!(close_at)
  end

  def finalize!(timestamp = Time.current)
    students = @school_class.students.to_a
    records = AttendanceRecord
              .where(school_class: @school_class, date: @class_session.date)
              .index_by(&:user_id)
    approved_requests = AttendanceRequest
                        .where(school_class: @school_class, date: @class_session.date, status: "approved")
                        .index_by(&:user_id)

    notifications = []

    students.each do |student|
      next if records[student.id].present?

      request = approved_requests[student.id]
      status = request&.request_type || "absent"

      record = AttendanceRecord.create!(
        user: student,
        school_class: @school_class,
        class_session: @class_session,
        date: @class_session.date,
        status: status,
        verification_method: "system",
        timestamp: timestamp
      )

      AttendanceChange.create!(
        attendance_record: record,
        user: student,
        school_class: @school_class,
        date: @class_session.date,
        previous_status: nil,
        new_status: status,
        reason: status == "absent" ? "出席確定(自動欠席)" : "出席確定(申請反映)",
        source: "system",
        changed_at: timestamp
      )

      if status == "absent"
        notifications << {
          user_id: student.id,
          kind: "warning",
          title: "欠席として記録されました",
          body: "#{@school_class.name} (#{@class_session.date.strftime('%Y-%m-%d')}) が欠席として記録されました。",
          action_path: Rails.application.routes.url_helpers.history_path(date: @class_session.date),
          created_at: Time.current,
          updated_at: Time.current
        }
      end
    end

    notifications.each { |attrs| Notification.create!(attrs) }
    @class_session.update!(locked_at: timestamp) unless @class_session.locked?
    true
  end
end
