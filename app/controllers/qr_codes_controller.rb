class QrCodesController < ApplicationController
  before_action -> { require_role!("teacher") }

  def show
    @classes = current_user.taught_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])

    return unless @selected_class

    @expires_at = Time.current + AttendanceToken::TOKEN_TTL
    @token = AttendanceToken.generate(
      class_id: @selected_class.id,
      teacher_id: current_user.id,
      expires_at: @expires_at
    )
  end
end
