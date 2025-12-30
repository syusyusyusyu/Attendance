require "csv"

class AttendanceChangesController < ApplicationController
  before_action -> { require_role!("teacher") }

  def index
    @classes = current_user.taught_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
    @source = params[:source].presence
    @status = params[:status].presence

    scope = AttendanceChange
            .includes(:user, :school_class, :modified_by)
            .order(changed_at: :desc)
    scope = scope.where(school_class: @selected_class) if @selected_class
    if @start_date || @end_date
      from = @start_date || @end_date
      to = @end_date || @start_date
      scope = scope.where(changed_at: from.beginning_of_day..to.end_of_day)
    end
    scope = scope.where(source: @source) if @source
    scope = scope.where(new_status: @status) if @status

    @changes = scope.limit(200)

    respond_to do |format|
      format.html
      format.csv do
        csv_data = CSV.generate(headers: true) do |csv|
          csv << ["変更時刻", "クラス", "学生ID", "氏名", "変更前", "変更後", "理由", "変更者", "種別", "IP", "UserAgent"]
          scope.limit(1000).each do |change|
            csv << [
              change.changed_at&.strftime("%Y-%m-%d %H:%M:%S"),
              change.school_class&.name,
              change.user&.student_id,
              change.user&.name,
              change.previous_status,
              change.new_status,
              change.reason,
              change.modified_by&.name,
              change.source,
              change.ip,
              change.user_agent
            ]
          end
        end
        send_data "\uFEFF#{csv_data}", filename: "attendance-changes.csv", type: "text/csv; charset=utf-8"
      end
    end
  rescue ArgumentError
    redirect_to attendance_logs_path, alert: "日付の形式が正しくありません。"
  end
end
