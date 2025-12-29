class AttendanceToken
  TOKEN_TTL = 5.minutes

  def self.generate(class_id:, teacher_id:, expires_at: nil)
    expires_at ||= Time.current + TOKEN_TTL
    payload = {
      class_id: class_id,
      teacher_id: teacher_id,
      exp: expires_at.to_i
    }

    verifier.generate(payload)
  end

  def self.verify(token)
    payload = verifier.verify(token)
    data = payload.transform_keys(&:to_s)
    expires_at = Time.at(data["exp"].to_i)

    if expires_at <= Time.current
      return { ok: false, error: "QRコードの有効期限が切れています。" }
    end

    {
      ok: true,
      class_id: data["class_id"],
      teacher_id: data["teacher_id"],
      expires_at: expires_at
    }
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    { ok: false, error: "QRコードが無効です。" }
  end

  def self.verifier
    ActiveSupport::MessageVerifier.new(
      Rails.application.secret_key_base,
      serializer: JSON
    )
  end
end
