class QrScanEventsController < ApplicationController
  before_action -> { require_role!("teacher") }

  def index
    @classes = current_user.taught_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])
    @date = params[:date].present? ? Date.parse(params[:date]) : nil
    @status = params[:status].presence
    @attendance_status = params[:attendance_status].presence

    scope = QrScanEvent.includes(:user, :school_class, :qr_session).order(scanned_at: :desc)
    scope = scope.where(school_class: @selected_class) if @selected_class
    if @date
      scope = scope.where(scanned_at: @date.beginning_of_day..@date.end_of_day)
    end
    scope = scope.where(status: @status) if @status
    scope = scope.where(attendance_status: @attendance_status) if @attendance_status

    @scan_events = scope.limit(200)
  rescue ArgumentError
    redirect_to scan_logs_path, alert: "日付の形式が正しくありません。"
  end
end
