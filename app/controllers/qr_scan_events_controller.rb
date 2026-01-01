require "csv"

class QrScanEventsController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("scan.logs.view") }

  def index
    @classes = current_user.manageable_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])
    @date = params[:date].present? ? Date.parse(params[:date]) : nil
    @status = params[:status].presence
    @attendance_status = params[:attendance_status].presence

    scope = QrScanEvent.includes(:user, :school_class, :qr_session).order(scanned_at: :desc)
    scope = scope.where(school_class: @selected_class) if @selected_class
    scope = scope.where(scanned_at: @date.beginning_of_day..@date.end_of_day) if @date
    scope = scope.where(status: @status) if @status
    scope = scope.where(attendance_status: @attendance_status) if @attendance_status

    @scan_events = scope.limit(200)

    respond_to do |format|
      format.html
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ["スキャン時刻", "クラス", "学籍ID", "氏名", "結果", "出席判定", "IP", "UserAgent"]
          scope.limit(1000).each do |event|
            csv << [
              event.scanned_at&.strftime("%Y-%m-%d %H:%M:%S"),
              event.school_class&.name,
              event.user&.student_id,
              event.user&.name,
              event.status,
              event.attendance_status,
              event.ip,
              event.user_agent
            ]
          end
        end
        send_data "\uFEFF#{csv_data}", filename: "qr-scan-events.csv", type: "text/csv; charset=utf-8"
      end
    end
  rescue ArgumentError
    redirect_to scan_logs_path, alert: "日付の形式が正しくありません。"
  end
end
