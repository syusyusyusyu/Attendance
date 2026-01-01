class OperationRequestProcessor
  def initialize(operation_request:, processed_by:, ip:, user_agent:)
    @request = operation_request
    @processed_by = processed_by
    @ip = ip
    @user_agent = user_agent
  end

  def approve!
    case @request.kind
    when "attendance_correction"
      apply_corrections!
    when "attendance_finalize"
      finalize_attendance!
    when "attendance_unlock"
      unlock_attendance!
    when "attendance_csv_import"
      import_attendance_csv!
    else
      raise ArgumentError, "unknown operation request kind"
    end
  end

  private

  def apply_corrections!
    payload = @request.payload || {}
    date = Date.parse(payload["date"].to_s)
    changes = Array(payload["changes"])
    reason = payload["reason"].to_s.strip

    class_session = ClassSessionResolver.new(school_class: @request.school_class, date: date).resolve&.dig(:session)

    changes.each do |item|
      user = User.find(item["user_id"])
      status = item["status"]

      record = AttendanceRecord.find_or_initialize_by(
        user: user,
        school_class: @request.school_class,
        date: date
      )
      previous_status = record.status

      record.status = status
      record.verification_method = "manual"
      record.timestamp ||= Time.current
      record.modified_by = @processed_by
      record.modified_at = Time.current
      record.class_session ||= class_session if class_session
      record.save!

      next if previous_status.nil? || previous_status == record.status

      change_reason = reason.present? ? "承認申請: #{reason}" : "承認申請"

      AttendanceChange.create!(
        attendance_record: record,
        user: user,
        school_class: @request.school_class,
        date: date,
        previous_status: previous_status,
        new_status: record.status,
        reason: change_reason,
        modified_by: @processed_by,
        source: "manual",
        ip: @ip,
        user_agent: @user_agent,
        changed_at: Time.current
      )

      Notification.create!(
        user: user,
        kind: "info",
        title: "出席状況が更新されました",
        body: "#{@request.school_class.name} (#{date.strftime('%Y-%m-%d')}) の出席が更新されました。",
        action_path: Rails.application.routes.url_helpers.history_path(date: date)
      )
    end
  end

  def finalize_attendance!
    payload = @request.payload || {}
    date = Date.parse(payload["date"].to_s)
    class_session = resolve_session(payload, date)
    raise ArgumentError, "class_session is missing" if class_session.blank?

    policy = @request.school_class.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
    AttendanceFinalizer.new(class_session: class_session, policy: policy).finalize!(Time.current)
  end

  def unlock_attendance!
    payload = @request.payload || {}
    date = Date.parse(payload["date"].to_s)
    class_session = resolve_session(payload, date)
    raise ArgumentError, "class_session is missing" if class_session.blank?

    class_session.update!(locked_at: nil)
  end

  def import_attendance_csv!
    payload = @request.payload || {}
    csv_text = payload["csv_text"].to_s

    result = AttendanceCsvImporter.new(
      teacher: @request.user,
      school_class: @request.school_class,
      csv_text: csv_text
    ).import

    if result[:errors].any?
      raise StandardError, result[:errors].first(3).join(" ")
    end
  end

  def resolve_session(payload, date)
    return ClassSession.find_by(id: payload["class_session_id"]) if payload["class_session_id"].present?

    ClassSessionResolver.new(school_class: @request.school_class, date: date).resolve&.dig(:session)
  end
end
