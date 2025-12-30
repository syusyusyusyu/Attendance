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

    record = AttendanceRecord.find_or_initialize_by(
      user: current_user,
      school_class: school_class,
      date: qr_session.attendance_date
    )

    if record.persisted? && record.status_present?
      log_scan_event(status: "duplicate", token: token, qr_session: qr_session)
      redirect_to scan_path, notice: "すでに出席済みです。" and return
    end

    record.status = "present"
    record.verification_method = "qrcode"
    record.timestamp = Time.current
    record.location = (record.location || {}).merge(
      "ip" => request.remote_ip,
      "user_agent" => request.user_agent,
      "qr_session_id" => qr_session.id,
      "scanned_at" => Time.current.iso8601
    )

    begin
      if record.save
        log_scan_event(status: "success", token: token, qr_session: qr_session)
        redirect_to scan_path, notice: "出席を記録しました。"
      else
        log_scan_event(status: "error", token: token, qr_session: qr_session)
        redirect_to scan_path, alert: "出席登録に失敗しました。"
      end
    rescue ActiveRecord::RecordNotUnique
      log_scan_event(status: "duplicate", token: token, qr_session: qr_session)
      redirect_to scan_path, notice: "すでに出席済みです。"
    end
  end

  private

  def log_scan_event(status:, token:, qr_session: nil, school_class_id: nil)
    QrScanEvent.create(
      status: status,
      token_digest: Digest::SHA256.hexdigest(token.to_s),
      qr_session: qr_session,
      user: current_user,
      school_class_id: school_class_id || qr_session&.school_class_id,
      ip: request.remote_ip,
      user_agent: request.user_agent,
      scanned_at: Time.current
    )
  end
end
