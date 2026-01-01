class QrCodesController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("qr.generate") }

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
      expires_at: issued_at + AttendanceToken::TOKEN_TTL
    )
    @expires_at = @qr_session.expires_at
    @token = AttendanceToken.generate(qr_session: @qr_session)
    @qr_svg = qr_svg(@token)

    respond_to do |format|
      format.html
      format.json do
        render json: {
          token: @token,
          expires_at: @expires_at.to_i,
          svg: @qr_svg
        }
      end
    end
  end

  private

  def qr_svg(token)
    qr = RQRCode::QRCode.new(token, level: :m)
    qr.as_svg(module_size: 8, border_modules: 4, fill: "ffffff", color: "0f172a", shape_rendering: "crispEdges")
  rescue RQRCode::QRCodeRunTimeError
    qr = RQRCode::QRCode.new(token)
    qr.as_svg(module_size: 6, border_modules: 4, fill: "ffffff", color: "0f172a", shape_rendering: "crispEdges")
  end
end
