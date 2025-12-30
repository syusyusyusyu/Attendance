class QrCodesController < ApplicationController
  before_action -> { require_role!("teacher") }

  def show
    @classes = current_user.taught_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])

    return unless @selected_class

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
  end
end
