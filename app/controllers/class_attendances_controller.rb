require "csv"

class ClassAttendancesController < ApplicationController
  before_action -> { require_role!("teacher") }

  def show
    @classes = current_user.taught_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    return unless @selected_class

    @students = @selected_class.students.order(:name)
    @records = AttendanceRecord
               .where(school_class: @selected_class, date: @date)
               .index_by(&:user_id)
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def update
    selected_class = current_user.taught_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    (params[:attendance] || {}).each do |user_id, status|
      record = AttendanceRecord.find_or_initialize_by(
        user_id: user_id,
        school_class: selected_class,
        date: date
      )
      record.status = status
      record.verification_method ||= "manual"
      record.timestamp ||= Time.current
      record.modified_by = current_user
      record.modified_at = Time.current
      record.save!
    end

    redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "出席を更新しました。"
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def export
    selected_class = current_user.taught_classes.find(params[:class_id])
    start_date = parse_date_param(params[:start_date]) || parse_date_param(params[:date]) || Date.current
    end_date = parse_date_param(params[:end_date]) || parse_date_param(params[:date]) || start_date

    if end_date < start_date
      start_date, end_date = end_date, start_date
    end

    students = selected_class.students.order(:name)
    records = AttendanceRecord
              .where(school_class: selected_class, date: start_date..end_date)
              .index_by { |record| [record.user_id, record.date] }

    dates = (start_date..end_date).to_a

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "日付",
        "クラス",
        "学生ID",
        "氏名",
        "出席状況",
        "記録時刻",
        "方法",
        "QRセッションID",
        "IP",
        "UserAgent",
        "備考"
      ]
      students.each do |student|
        dates.each do |date|
          record = records[[student.id, date]]
          location = record&.location || {}
          csv << [
            date.strftime("%Y-%m-%d"),
            selected_class.name,
            student.student_id,
            student.name,
            record&.status_label || "未入力",
            record&.timestamp&.strftime("%H:%M:%S"),
            record&.verification_method,
            location["qr_session_id"],
            location["ip"],
            location["user_agent"],
            record&.notes
          ]
        end
      end
    end

    filename = "attendance-#{selected_class.id}-#{start_date.strftime('%Y%m%d')}-#{end_date.strftime('%Y%m%d')}.csv"
    send_data "\uFEFF#{csv_data}", filename: filename, type: "text/csv; charset=utf-8"
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  private

  def parse_date_param(value)
    return nil if value.blank?

    Date.parse(value)
  end
end
