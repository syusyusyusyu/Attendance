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
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    students = selected_class.students.order(:name)
    records = AttendanceRecord.where(school_class: selected_class, date: date).index_by(&:user_id)

    csv_data = CSV.generate(headers: true) do |csv|
      csv << ["日付", "学生ID", "氏名", "出席状況", "記録時刻", "方法"]
      students.each do |student|
        record = records[student.id]
        csv << [
          date.strftime("%Y-%m-%d"),
          student.student_id,
          student.name,
          record&.status_label || "未入力",
          record&.timestamp&.strftime("%H:%M"),
          record&.verification_method
        ]
      end
    end

    filename = "attendance-#{selected_class.id}-#{date.strftime('%Y%m%d')}.csv"
    send_data "\uFEFF#{csv_data}", filename: filename, type: "text/csv; charset=utf-8"
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end
end
