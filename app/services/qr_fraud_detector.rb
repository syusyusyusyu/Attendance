class QrFraudDetector
  FAILURE_STATUSES = %w[
    invalid
    expired
    revoked
    wrong_date
    session_missing
    rate_limited
    manual_override
  ].freeze

  def initialize(event:)
    @event = event
    @school_class = event.school_class
    @teacher = @school_class&.teacher
    @policy = @school_class&.attendance_policy
  end

  def call
    return unless @teacher

    notify_blocked_access
    detect_failure_burst
    detect_token_sharing
    detect_ip_burst
  end

  private

  def notify_blocked_access
    return unless @event.status_ip_blocked? || @event.status_device_blocked?

    reason = @event.status_ip_blocked? ? "IP制限" : "端末制限"
    key = "qr_fraud:block:#{@event.status}:#{@event.school_class_id}:#{minute_key}"
    notify_once!(
      key,
      title: "不正スキャンの疑い: #{reason}",
      body: "#{@school_class.name} で#{reason}に該当するスキャンが検知されました。(IP: #{@event.ip})",
      action_path: Rails.application.routes.url_helpers.scan_logs_path(status: @event.status, class_id: @school_class.id)
    )
  end

  def detect_failure_burst
    return unless FAILURE_STATUSES.include?(@event.status)

    key = "qr_fraud:failures:#{@event.school_class_id}:#{minute_key}"
    count = Rails.cache.increment(key, 1, expires_in: 2.minutes)
    threshold = 4

    return if count < threshold

    notify_once!(
      "qr_fraud:failures_alerted:#{@event.school_class_id}:#{minute_key}",
      title: "不正スキャンの疑い: 同時刻の失敗多発",
      body: "#{@school_class.name} で失敗スキャンが短時間に多発しています。",
      action_path: Rails.application.routes.url_helpers.scan_logs_path(class_id: @school_class.id)
    )
  end

  def detect_token_sharing
    return if @event.token_digest.blank?

    window = 2.minutes.ago..Time.current
    user_ids = QrScanEvent
               .where(token_digest: @event.token_digest, scanned_at: window)
               .where.not(user_id: nil)
               .distinct
               .pluck(:user_id)

    return if user_ids.size < 2

    notify_once!(
      "qr_fraud:token_share:#{@event.token_digest}",
      title: "不正スキャンの疑い: トークン共有",
      body: "#{@school_class.name} で同一QRが複数ユーザーにより使用されました。",
      action_path: Rails.application.routes.url_helpers.scan_logs_path(class_id: @school_class.id)
    )
  end

  def detect_ip_burst
    return if @event.ip.blank?

    window = 1.minute.ago..Time.current
    count = QrScanEvent.where(ip: @event.ip, scanned_at: window).count
    threshold = [@policy&.max_scans_per_minute.to_i, 8].max

    return if count < threshold

    notify_once!(
      "qr_fraud:ip_burst:#{@event.ip}:#{minute_key}",
      title: "不正スキャンの疑い: 同一IPの集中アクセス",
      body: "#{@school_class.name} で同一IPから短時間に多数のスキャンが発生しました。(IP: #{@event.ip})",
      action_path: Rails.application.routes.url_helpers.scan_logs_path(class_id: @school_class.id)
    )
  end

  def notify_once!(key, title:, body:, action_path:)
    return if Rails.cache.read(key)

    Rails.cache.write(key, true, expires_in: 5.minutes)
    Notification.create!(
      user: @teacher,
      kind: "warning",
      title: title,
      body: body,
      action_path: action_path
    )
  end

  def minute_key
    Time.current.strftime("%Y%m%d%H%M")
  end
end
