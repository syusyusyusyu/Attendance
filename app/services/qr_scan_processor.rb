require "uri"

class QrScanProcessor
  Result = Struct.new(:flash, :message, keyword_init: true)

  def initialize(user:, token:, ip:, user_agent:, device:, now: Time.current)
    @user = user
    @raw_token = token
    @ip = ip
    @user_agent = user_agent
    @device = device
    @now = now
    @logger = QrScanEventLogger.new(user: user, ip: ip, user_agent: user_agent)
  end

  def call
    token = normalize_token(@raw_token)
    if token.blank?
      @logger.log(status: "invalid", token: token)
      return alert("QRコードが読み取れませんでした。明るい場所で再度スキャンするか、手入力をご利用ください。")
    end

    limiter = QrScanRateLimiter.new(user_id: @user.id, now: @now)
    if limiter.user_limited?(limit: AttendancePolicy::DEFAULTS[:student_max_scans_per_minute])
      @logger.log(status: "rate_limited", token: token)
      return alert("短時間に連続スキャンされています。1分ほど待って再試行してください。")
    end

    result = AttendanceToken.verify(token)
    unless result[:ok]
      @logger.log(status: result[:status] || "invalid", token: token)
      return alert(result[:error])
    end

    qr_session = QrSession.find_by(id: result[:session_id])
    unless qr_session
      @logger.log(status: "session_missing", token: token, school_class_id: result[:class_id])
      return alert("このQRコードは無効です。教員に新しいQRの表示を依頼してください。")
    end

    if qr_session.revoked?
      @logger.log(status: "revoked", token: token, qr_session: qr_session)
      return alert("このQRコードは更新済みです。新しいQRを読み取ってください。")
    end

    if qr_session.expires_at <= @now
      @logger.log(status: "expired", token: token, qr_session: qr_session)
      return alert("QRコードの有効期限が切れています。教員に再表示を依頼してください。")
    end

    if result[:attendance_date] != qr_session.attendance_date
      @logger.log(status: "wrong_date", token: token, qr_session: qr_session)
      return alert("このQRは本日の授業ではありません。")
    end

    school_class = @user.enrolled_classes.find_by(id: qr_session.school_class_id)
    unless school_class
      @logger.log(status: "not_enrolled", token: token, qr_session: qr_session)
      return alert("履修登録がないため出席登録できません。教員に確認してください。")
    end

    policy = school_class.attendance_policy || school_class.create_attendance_policy(AttendancePolicy.default_attributes)

    limiter = QrScanRateLimiter.new(user_id: @user.id, class_id: school_class.id, now: @now)
    if limiter.class_limited?(limit: policy.rate_limit_policy.class_limit)
      @logger.log(status: "rate_limited", token: token, qr_session: qr_session)
      return alert("この授業のスキャンが集中しています。1分ほど待って再試行してください。")
    end

    if limiter.user_limited?(limit: policy.rate_limit_policy.student_limit)
      @logger.log(status: "rate_limited", token: token, qr_session: qr_session)
      return alert("短時間に連続スキャンされています。1分ほど待って再試行してください。")
    end

    if policy.allowed_ip_ranges_list.any? && !policy.ip_allowed?(@ip)
      @logger.log(status: "ip_blocked", token: token, qr_session: qr_session)
      return alert("許可されていないネットワークからのアクセスです。教室内で再試行してください。")
    end

    if policy.allowed_user_agent_keywords_list.any? && !policy.user_agent_allowed?(@user_agent)
      @logger.log(status: "device_blocked", token: token, qr_session: qr_session)
      return alert("許可されていない端末からのアクセスです。別の端末で再試行してください。")
    end

    if policy.require_registered_device && (@device.blank? || !@device.approved?)
      @logger.log(status: "device_blocked", token: token, qr_session: qr_session)
      return alert("公認端末のみ出席登録できます。端末登録を申請してください。")
    end

    if @device.present?
      @device.update(last_seen_at: @now, ip: @ip, user_agent: @user_agent)
    end

    window = school_class.schedule_window(qr_session.attendance_date)
    unless window
      @logger.log(status: "no_schedule", token: token, qr_session: qr_session)
      return alert("本日の授業予定がありません。")
    end

    if window[:canceled]
      @logger.log(status: "class_canceled", token: token, qr_session: qr_session)
      return alert("本日の授業は休講です。")
    end

    class_session = window[:class_session]
    if class_session&.locked?
      @logger.log(status: "session_locked", token: token, qr_session: qr_session)
      return alert("この授業は出席確定済みのため登録できません。")
    end

    record = AttendanceRecord.find_or_initialize_by(
      user: @user,
      school_class: school_class,
      date: qr_session.attendance_date
    )
    record.class_session ||= class_session if class_session
    record.checked_in_at ||= record.timestamp if record.timestamp.present?
    previous_status = record.status

    if record.persisted?
      if record.modified_by_id.present? || record.verification_method_manual? || record.verification_method_system?
        @logger.log(status: "manual_override", token: token, qr_session: qr_session, attendance_status: record.status)
        return alert("教員が出席を確定済みのためスキャンできません。")
      end
    end

    if record.persisted? && record.verification_method_qrcode? && record.checked_in_at.present?
      return handle_checkout(record, previous_status, window, qr_session, token, school_class, policy)
    end

    checkin_start_at = qr_session.issued_at || window[:start_at]
    policy_result = policy.evaluate(scan_time: @now, start_at: checkin_start_at, mode: :checkin)

    unless policy_result[:allowed]
      @logger.log(status: policy_result[:status], token: token, qr_session: qr_session)
      return alert(policy_result[:message])
    end

    if record.persisted? && record.verification_method_qrcode?
      @logger.log(status: "duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
      return notice("すでに出席済みです。")
    end

    record.status = "present"
    record.verification_method = "qrcode"
    record.timestamp = @now
    record.checked_in_at ||= @now
    record.location = (record.location || {}).merge(
      "ip" => @ip,
      "user_agent" => @user_agent,
      "qr_session_id" => qr_session.id,
      "checked_in_at" => @now.iso8601
    )

    begin
      if record.save
        @logger.log(status: "success", token: token, qr_session: qr_session, attendance_status: record.status)
        log_attendance_change(record, previous_status, school_class, qr_session, "QRスキャン")
        return notice("出席を記録しました。")
      end
    rescue ActiveRecord::RecordNotUnique
      @logger.log(status: "duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
      return notice("すでに出席済みです。")
    end

    @logger.log(status: "error", token: token, qr_session: qr_session)
    alert("出席登録に失敗しました。")
  end

  private

  def handle_checkout(record, previous_status, window, qr_session, token, school_class, policy)
    if record.checked_out_at.present?
      @logger.log(status: "checkout_duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
      return notice("すでに退室済みです。")
    end

    record.checked_out_at = @now
    record.location = (record.location || {}).merge(
      "ip" => @ip,
      "user_agent" => @user_agent,
      "qr_session_id" => qr_session.id,
      "checked_out_at" => @now.iso8601
    )

    if policy.early_leave?(
      checked_in_at: record.checked_in_at,
      checked_out_at: @now,
      session_start_at: window[:start_at],
      session_end_at: window[:end_at]
    )
      record.status = "early_leave"
    end

    begin
      if record.save
        @logger.log(status: "checkout", token: token, qr_session: qr_session, attendance_status: record.status)
        log_attendance_change(record, previous_status, school_class, qr_session, "QR退室")
        notify_early_leave(record, school_class, qr_session) if record.status_early_leave?
        return notice("退室を記録しました。")
      end
    rescue ActiveRecord::RecordNotUnique
      @logger.log(status: "checkout_duplicate", token: token, qr_session: qr_session, attendance_status: record.status)
      return notice("すでに退室済みです。")
    end

    @logger.log(status: "error", token: token, qr_session: qr_session)
    alert("退室登録に失敗しました。")
  end

  def log_attendance_change(record, previous_status, school_class, qr_session, reason)
    return if previous_status.blank? || previous_status == record.status

    AttendanceChange.create!(
      attendance_record: record,
      user: @user,
      school_class: school_class,
      date: qr_session.attendance_date,
      previous_status: previous_status,
      new_status: record.status,
      reason: reason,
      modified_by: @user,
      source: "system",
      ip: @ip,
      user_agent: @user_agent,
      changed_at: @now
    )
  end

  def notify_early_leave(record, school_class, qr_session)
    Notification.create!(
      user: @user,
      kind: "warning",
      title: "早退として記録されました",
      body: "#{school_class.name} (#{qr_session.attendance_date.strftime('%Y-%m-%d')}) が早退として登録されました。",
      action_path: Rails.application.routes.url_helpers.history_path(date: qr_session.attendance_date)
    )
  end

  def alert(message)
    Result.new(flash: :alert, message: message)
  end

  def notice(message)
    Result.new(flash: :notice, message: message)
  end

  def normalize_token(raw)
    text = raw.to_s.strip
    return "" if text.blank?

    text = text.gsub(/\s+/, "")
    return text unless text.match?(/\Ahttps?:/i)

    begin
      uri = URI.parse(text)
      token_param = Rack::Utils.parse_nested_query(uri.query.to_s)["token"]
      token_param.presence || text
    rescue URI::InvalidURIError
      text
    end
  end
end
