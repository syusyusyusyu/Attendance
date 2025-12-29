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
end
