class AttendanceHistoryController < ApplicationController
  before_action -> { require_role!("student") }

  def show
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @records = current_user.attendance_records
                             .includes(:school_class)
                             .where(date: @date)
                             .order(:timestamp)
  rescue ArgumentError
    redirect_to history_path, alert: "日付の形式が正しくありません。"
  end
end
