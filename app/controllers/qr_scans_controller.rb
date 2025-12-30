require "digest"

class QrScansController < ApplicationController
  before_action -> { require_role!("student") }

  def new
  end

  def create
    token = params[:token].to_s.strip

    if token.blank?
      log_scan_event(status: "invalid", token: token)
      redirect_to scan_path, alert: "QRコードが無効です。" and return
    end

    if rate_limited?(token, limit: AttendancePolicy::DEFAULTS[:max_scans_per_minute])
      log_scan_event(status: "rate_limited", token: token)
      redirect_to scan_path, alert: "スキャン回数が多すぎます。少し待ってから再試行してください。" and return
    end

    result = AttendanceToken.verify(token)

    unless result[:ok]
      log_scan_event(status: result[:status] || "invalid", token: token)
      redirect_to scan_path, alert: result[:error] and return
    end

    qr_session = QrSession.find_by(id: result[:session_id])
    unless qr_session
      log_scan_event(status: "session_missing", token: token, school_class_id: result[:class_id])
      redirect_to scan_path, alert: "QRコードが無効です。" and return
    end

    if qr_session.revoked?
      log_scan_event(status: "revoked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "このQRコードは無効になりました。" and return
    end

    if qr_session.expires_at <= Time.current
      log_scan_event(status: "expired", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "QRコードの有効期限が切れています。" and return
    end

    if result[:attendance_date] != qr_session.attendance_date
      log_scan_event(status: "wrong_date", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "QRコードが無効です。" and return
    end

    school_class = current_user.enrolled_classes.find_by(id: qr_session.school_class_id)
    unless school_class
      log_scan_event(status: "not_enrolled", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "この授業には履修登録されていません。" and return
    end

    scan_time = Time.current
    policy = school_class.attendance_policy || school_class.create_attendance_policy(AttendancePolicy.default_attributes)

    if rate_limited?(token, limit: policy.max_scans_per_minute)
      log_scan_event(status: "rate_limited", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "スキャン回数が多すぎます。少し待ってから再試行してください。" and return
    end

    if policy.allowed_ip_ranges_list.any? && !policy.ip_allowed?(request.remote_ip)
      log_scan_event(status: "ip_blocked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "許可されていない端末/ネットワークからのアクセスです。" and return
    end

    if policy.allowed_user_agent_keywords_list.any? && !policy.user_agent_allowed?(request.user_agent)
      log_scan_event(status: "device_blocked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "許可されていない端末からのアクセスです。" and return
    end

    window = school_class.schedule_window(qr_session.attendance_date)
    unless window
      log_scan_event(status: "no_schedule", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "授業予定がありません。" and return
    end

    if window&.dig(:canceled)
      log_scan_event(status: "class_canceled", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "この授業は休講です。" and return
    end

    class_session = window[:class_session]
    if class_session&.locked?
      log_scan_event(status: "session_locked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "この授業の出席は確定済みです。" and return
    end

    record = AttendanceRecord.find_or_initialize_by(
      user: current_user,
      school_class: school_class,
      date: qr_session.attendance_date
    )
    record.class_session ||= class_session if class_session
    record.checked_in_at ||= record.timestamp if record.timestamp.present?
    previous_status = record.status

    if record.persisted?
      if record.modified_by_id.present? || record.verification_method_manual? || record.verification_method_system?
        log_scan_event(status: "manual_override", token: token, qr_session: qr_session, attendance_status: record.status)
        redirect_to scan_path, alert: "教員が出席を確定済みです。" and return
      end
    end

    if record.persisted? && record.verification_method_qrcode? && record.checked_in_at.present?
      if record.checked_out_at.present?
        log_scan_event(status: "checkout_duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
        redirect_to scan_path, notice: "すでに退室済みです。" and return
      end

      record.checked_out_at = scan_time
      record.location = (record.location || {}).merge(
        "ip" => request.remote_ip,
        "user_agent" => request.user_agent,
        "qr_session_id" => qr_session.id,
        "checked_out_at" => scan_time.iso8601
      )

      if policy.early_leave?(
        checked_in_at: record.checked_in_at,
        checked_out_at: scan_time,
        session_start_at: window[:start_at],
        session_end_at: window[:end_at]
      )
        record.status = "early_leave"
      end

      begin
        if record.save
          log_scan_event(status: "checkout", token: token, qr_session: qr_session, attendance_status: record.status)

          if previous_status.present? && previous_status != record.status
            AttendanceChange.create!(
              attendance_record: record,
              user: current_user,
              school_class: school_class,
              date: qr_session.attendance_date,
              previous_status: previous_status,
              new_status: record.status,
              reason: "QR退室",
              source: "system",
              ip: request.remote_ip,
              user_agent: request.user_agent,
              changed_at: Time.current
            )
          end

          if record.status_early_leave?
            Notification.create!(
              user: current_user,
              kind: "warning",
              title: "早退として記録されました",
              body: "#{school_class.name} (#{qr_session.attendance_date.strftime('%Y-%m-%d')}) が早退として登録されました。",
              action_path: history_path(date: qr_session.attendance_date)
            )
          end

          redirect_to scan_path, notice: "退室を記録しました。"
        else
          log_scan_event(status: "error", token: token, qr_session: qr_session)
          redirect_to scan_path, alert: "退室登録に失敗しました。"
        end
      rescue ActiveRecord::RecordNotUnique
        log_scan_event(status: "checkout_duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
        redirect_to scan_path, notice: "すでに退室済みです。"
      end

      return
    end

    policy_result = policy.evaluate(scan_time: scan_time, start_at: window[:start_at], mode: :checkin)

    unless policy_result[:allowed]
      log_scan_event(status: policy_result[:status], token: token, qr_session: qr_session)
      redirect_to scan_path, alert: policy_result[:message] and return
    end

    attendance_status = policy_result[:attendance_status] || "present"

    if record.persisted? && record.verification_method_qrcode?
      log_scan_event(status: "duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
      redirect_to scan_path, notice: "すでに出席済みです。" and return
    end

    record.status = attendance_status
    record.verification_method = "qrcode"
    record.timestamp = scan_time
    record.checked_in_at ||= scan_time
    record.location = (record.location || {}).merge(
      "ip" => request.remote_ip,
      "user_agent" => request.user_agent,
      "qr_session_id" => qr_session.id,
      "checked_in_at" => scan_time.iso8601
    )

    begin
      if record.save
        log_scan_event(status: "success", token: token, qr_session: qr_session, attendance_status: record.status)

        if previous_status.present? && previous_status != record.status
          AttendanceChange.create!(
            attendance_record: record,
            user: current_user,
            school_class: school_class,
            date: qr_session.attendance_date,
            previous_status: previous_status,
            new_status: record.status,
            reason: "QRスキャン",
            source: "system",
            ip: request.remote_ip,
            user_agent: request.user_agent,
            changed_at: Time.current
          )
        end

        if record.status_late?
          Notification.create!(
            user: current_user,
            kind: "warning",
            title: "遅刻として記録されました",
            body: "#{school_class.name} (#{qr_session.attendance_date.strftime('%Y-%m-%d')}) が遅刻として登録されました。",
            action_path: history_path(date: qr_session.attendance_date)
          )
        end

        redirect_to scan_path, notice: "出席を記録しました。"
      else
        log_scan_event(status: "error", token: token, qr_session: qr_session)
        redirect_to scan_path, alert: "出席登録に失敗しました。"
      end
    rescue ActiveRecord::RecordNotUnique
      log_scan_event(status: "duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
      redirect_to scan_path, notice: "すでに出席済みです。"
    end
  end

  private

  def log_scan_event(status:, token:, qr_session: nil, school_class_id: nil, attendance_status: nil)
    QrScanEvent.create(
      status: status,
      token_digest: Digest::SHA256.hexdigest(token.to_s),
      qr_session: qr_session,
      user: current_user,
      school_class_id: school_class_id || qr_session&.school_class_id,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      scanned_at: Time.current,
      attendance_status: attendance_status
    )
  end

  def rate_limited?(token, limit:)
    return false if token.blank?

    key = "qr_scan:#{current_user.id}:#{Time.current.strftime('%Y%m%d%H%M')}"
    count = Rails.cache.increment(key, 1, expires_in: 60)
    count.present? && count > limit
  end
end
