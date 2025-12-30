class AttendanceToken
  TOKEN_TTL = 5.minutes
  PURPOSE = "attendance-qr"

  def self.generate(class_id: nil, teacher_id: nil, expires_at: nil, attendance_date: nil, session_id: nil, qr_session: nil)
    if qr_session
      class_id = qr_session.school_class_id
      teacher_id = qr_session.teacher_id
      expires_at = qr_session.expires_at
      attendance_date = qr_session.attendance_date
      session_id = qr_session.id
    end

    raise ArgumentError, "class_id is required" if class_id.blank?
    raise ArgumentError, "teacher_id is required" if teacher_id.blank?

    expires_at ||= Time.current + TOKEN_TTL
    attendance_date ||= Time.zone.today

    payload = {
      class_id: class_id,
      teacher_id: teacher_id,
      session_id: session_id,
      date: attendance_date.to_s,
      exp: expires_at.to_i
    }

    verifier.generate(payload, purpose: PURPOSE)
  end

  def self.verify(token)
    payload = verifier.verify(token, purpose: PURPOSE)
    data = payload.transform_keys(&:to_s)
    expires_at = Time.at(data["exp"].to_i)
    attendance_date = Date.iso8601(data["date"].to_s)

    if expires_at <= Time.current
      return { ok: false, error: "QRコードの有効期限が切れています。", status: "expired" }
    end

    {
      ok: true,
      class_id: data["class_id"],
      teacher_id: data["teacher_id"],
      session_id: data["session_id"],
      attendance_date: attendance_date,
      expires_at: expires_at
    }
  rescue ArgumentError
    { ok: false, error: "QRコードが無効です。", status: "invalid" }
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    { ok: false, error: "QRコードが無効です。", status: "invalid" }
  end

  def self.verifier
    ActiveSupport::MessageVerifier.new(
      ENV.fetch("QR_TOKEN_SECRET", Rails.application.secret_key_base),
      serializer: JSON,
      digest: "SHA256"
    )
  end
end
