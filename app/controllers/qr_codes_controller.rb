class QrCodesController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("qr.generate") }

  require "base64"

  def show
    @classes = current_user.manageable_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])

    unless @selected_class
      respond_to do |format|
        format.html
        format.json { render json: { error: "class_id is required" }, status: :unprocessable_entity }
      end
      return
    end

    @class_session = ClassSessionResolver.new(school_class: @selected_class, date: Time.zone.today).resolve&.dig(:session)

    QrSession
      .where(school_class: @selected_class, attendance_date: Time.zone.today, revoked_at: nil)
      .where("expires_at > ?", Time.current)
      .update_all(revoked_at: Time.current)

    issued_at = Time.current
    @qr_session = QrSession.create!(
      school_class: @selected_class,
      teacher: current_user,
      attendance_date: Time.zone.today,
      issued_at: issued_at,
      expires_at: issued_at + AttendanceToken::TOKEN_TTL,
      demo_mode: params[:demo_mode] == "1"
    )
    @expires_at = @qr_session.expires_at
    @token = AttendanceToken.generate(qr_session: @qr_session)
    @qr_image_url = qr_png_data_url(@token)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          token: @token,
          expires_at: @expires_at.to_i,
          png_data_url: @qr_image_url
        }
      end
    end
  end

  private

  def qr_png_data_url(token)
    png = RQRCode::QRCode.new(token, level: :m).as_png(
      size: 320,
      border_modules: 4,
      fill: "#ffffff",
      color: "#000000"
    )
    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  rescue RQRCode::QRCodeRunTimeError
    png = RQRCode::QRCode.new(token).as_png(
      size: 280,
      border_modules: 4,
      fill: "#ffffff",
      color: "#000000"
    )
    "data:image/png;base64,#{Base64.strict_encode64(png.to_s)}"
  end
end
