class ReportsController < ApplicationController
  before_action -> { require_role!("teacher") }

  def index
    @classes = current_user.taught_classes.includes(:students).order(:name)
    @start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : 30.days.ago.to_date
    @end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    @end_date = @start_date if @end_date < @start_date

    class_ids = @classes.map(&:id)
    records = AttendanceRecord
              .includes(:user)
              .where(school_class_id: class_ids, date: @start_date..@end_date)
              .to_a

    records_by_class_date = records.group_by { |record| [record.school_class_id, record.date] }

    @class_stats = @classes.map do |klass|
      dates = records_by_class_date.keys.filter { |pair| pair[0] == klass.id }.map(&:last).uniq
      total_students = klass.students.size
      totals = { present: 0, late: 0, excused: 0, early_leave: 0, absent: 0, missing: 0 }

      dates.each do |date|
        daily = records_by_class_date[[klass.id, date]] || []
        counts = daily.group_by(&:status).transform_values(&:count)
        totals[:present] += counts["present"].to_i
        totals[:late] += counts["late"].to_i
        totals[:excused] += counts["excused"].to_i
        totals[:early_leave] += counts["early_leave"].to_i
        totals[:absent] += counts["absent"].to_i
        totals[:missing] += [total_students - daily.size, 0].max
      end

      expected = total_students * dates.size
      rate =
        if expected.zero?
          0
        else
          ((totals[:present] + totals[:late] + totals[:excused]) * 100.0 / expected).round
        end

      {
        klass: klass,
        total_students: total_students,
        dates_count: dates.size,
        totals: totals,
        rate: rate
      }
    end

    student_counts = records.group_by(&:user_id).map do |user_id, items|
      user = items.first.user
      counts = items.group_by(&:status).transform_values(&:count)
      {
        user: user,
        present: counts["present"].to_i,
        late: counts["late"].to_i,
        excused: counts["excused"].to_i,
        early_leave: counts["early_leave"].to_i,
        absent: counts["absent"].to_i
      }
    end

    @student_ranking = student_counts.sort_by { |row| -(row[:absent] + row[:early_leave]) }.first(5)

    date_range = (@start_date..@end_date).to_a
    @daily_summary = date_range.map do |date|
      daily = records.select { |record| record.date == date }
      counts = daily.group_by(&:status).transform_values(&:count)
      {
        date: date,
        present: counts["present"].to_i,
        late: counts["late"].to_i,
        excused: counts["excused"].to_i,
        early_leave: counts["early_leave"].to_i,
        absent: counts["absent"].to_i
      }
    end
  rescue ArgumentError
    redirect_to reports_path, alert: "日付の形式が正しくありません。"
  end
end
