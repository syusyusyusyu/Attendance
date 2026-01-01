require "digest"

class QrScansController < ApplicationController
  before_action -> { require_role!("student") }
  before_action -> { require_permission!("qr.scan") }

  def new
  end

  def create
    token = params[:token].to_s.strip

    if token.blank?
      log_scan_event(status: "invalid", token: token)
      redirect_to scan_path,
                  alert: "QRコードが読み取れませんでした。明るい場所で再度スキャンするか、手入力をご利用ください。" and return
    end

    if rate_limited_for_user?(limit: AttendancePolicy::DEFAULTS[:student_max_scans_per_minute])
      log_scan_event(status: "rate_limited", token: token)
      redirect_to scan_path, alert: "短時間に連続スキャンされています。1分ほど待って再試行してください。" and return
    end

    result = AttendanceToken.verify(token)

    unless result[:ok]
      log_scan_event(status: result[:status] || "invalid", token: token)
      redirect_to scan_path, alert: result[:error] and return
    end

    qr_session = QrSession.find_by(id: result[:session_id])
    unless qr_session
      log_scan_event(status: "session_missing", token: token, school_class_id: result[:class_id])
      redirect_to scan_path, alert: "このQRコードは無効です。教員に新しいQRの表示を依頼してください。" and return
    end

    if qr_session.revoked?
      log_scan_event(status: "revoked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "このQRコードは更新済みです。新しいQRを読み取ってください。" and return
    end

    if qr_session.expires_at <= Time.current
      log_scan_event(status: "expired", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "QRコードの有効期限が切れています。教員に再表示を依頼してください。" and return
    end

    if result[:attendance_date] != qr_session.attendance_date
      log_scan_event(status: "wrong_date", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "このQRは本日の授業ではありません。" and return
    end

    school_class = current_user.enrolled_classes.find_by(id: qr_session.school_class_id)
    unless school_class
      log_scan_event(status: "not_enrolled", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "履修登録がないため出席登録できません。教員に確認してください。" and return
    end

    scan_time = Time.current
    policy = school_class.attendance_policy || school_class.create_attendance_policy(AttendancePolicy.default_attributes)

    if rate_limited_for_class?(school_class.id, limit: policy.max_scans_per_minute)
      log_scan_event(status: "rate_limited", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "この授業のスキャンが集中しています。1分ほど待って再試行してください。" and return
    end

    if rate_limited_for_user?(limit: policy.student_max_scans_per_minute)
      log_scan_event(status: "rate_limited", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "短時間に連続スキャンされています。1分ほど待って再試行してください。" and return
    end

    if policy.allowed_ip_ranges_list.any? && !policy.ip_allowed?(request.remote_ip)
      log_scan_event(status: "ip_blocked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "許可されていないネットワークからのアクセスです。教室内で再試行してください。" and return
    end

    if policy.allowed_user_agent_keywords_list.any? && !policy.user_agent_allowed?(request.user_agent)
      log_scan_event(status: "device_blocked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "許可されていない端末からのアクセスです。別の端末で再試行してください。" and return
    end

    device = current_device
    if policy.require_registered_device && (device.blank? || !device.approved?)
      log_scan_event(status: "device_blocked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "公認端末のみ出席登録できます。端末登録を申請してください。" and return
    end

    if device.present?
      device.update(last_seen_at: Time.current, ip: request.remote_ip, user_agent: request.user_agent)
    end

    window = school_class.schedule_window(qr_session.attendance_date)
    unless window
      log_scan_event(status: "no_schedule", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "本日の授業予定がありません。" and return
    end

    if window&.dig(:canceled)
      log_scan_event(status: "class_canceled", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "本日の授業は休講です。" and return
    end

    class_session = window[:class_session]
    if class_session&.locked?
      log_scan_event(status: "session_locked", token: token, qr_session: qr_session)
      redirect_to scan_path, alert: "この授業は出席確定済みのため登録できません。" and return
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
        redirect_to scan_path, alert: "教員が出席を確定済みのためスキャンできません。" and return
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

    checkin_start_at = qr_session.issued_at || window[:start_at]
    policy_result = policy.evaluate(scan_time: scan_time, start_at: checkin_start_at, mode: :checkin)

    unless policy_result[:allowed]
      log_scan_event(status: policy_result[:status], token: token, qr_session: qr_session)
      redirect_to scan_path, alert: policy_result[:message] and return
    end

    attendance_status = "present"

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
    event = QrScanEvent.create(
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

    QrFraudDetector.new(event: event).call if event.persisted?
  end

  def rate_limited_for_user?(limit:)
    return false if limit.to_i <= 0

    key = "qr_scan:user:#{current_user.id}:#{Time.current.strftime('%Y%m%d%H%M')}"
    count = Rails.cache.increment(key, 1, expires_in: 60)
    count.present? && count > limit
  end

  def rate_limited_for_class?(class_id, limit:)
    return false if class_id.blank? || limit.to_i <= 0

    key = "qr_scan:class:#{class_id}:#{Time.current.strftime('%Y%m%d%H%M')}"
    count = Rails.cache.increment(key, 1, expires_in: 60)
    count.present? && count > limit
  end
end
