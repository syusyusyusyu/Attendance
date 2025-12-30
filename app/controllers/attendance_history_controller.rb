class AttendanceHistoryController < ApplicationController
  before_action -> { require_role!("student") }

  def show
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    @month_start = @date.beginning_of_month
    @month_end = @date.end_of_month
    @prev_month = @date.prev_month
    @next_month = @date.next_month

    month_records = current_user.attendance_records
                                .where(date: @month_start..@month_end)

    @status_by_date = month_records.group_by(&:date).transform_values do |records|
      statuses = records.map(&:status)
      if statuses.include?("absent")
        "absent"
      elsif statuses.include?("late")
        "late"
      else
        "present"
      end
    end

    @records = current_user.attendance_records
                           .includes(:school_class)
                           .where(date: @date)
                           .order(:timestamp)

    record_ids = @records.map(&:id)
    @changes_by_record = AttendanceChange
                         .where(attendance_record_id: record_ids)
                         .order(changed_at: :desc)
                         .group_by(&:attendance_record_id)
                         .transform_values { |items| items.first }
  rescue ArgumentError
    redirect_to history_path, alert: "日付の形式が正しくありません。"
  end
end
