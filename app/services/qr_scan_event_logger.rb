require "digest"

class QrScanEventLogger
  def initialize(user:, ip:, user_agent:)
    @user = user
    @ip = ip
    @user_agent = user_agent
  end

  def log(status:, token:, qr_session: nil, school_class_id: nil, attendance_status: nil)
    event = QrScanEvent.create(
      status: status,
      token_digest: Digest::SHA256.hexdigest(token.to_s),
      qr_session: qr_session,
      user: @user,
      school_class_id: school_class_id || qr_session&.school_class_id,
      ip: @ip,
      user_agent: @user_agent,
      scanned_at: Time.current,
      attendance_status: attendance_status
    )

    QrFraudDetector.new(event: event).call if event.persisted?
    event
  end
end
