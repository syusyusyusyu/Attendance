class DashboardController < ApplicationController
  def show
    @user = current_user
    if @user.teacher?
      @classes = @user.taught_classes.order(:name)
      class_ids = @classes.pluck(:id)
      today = Time.zone.today

      totals = Enrollment.where(school_class_id: class_ids).group(:school_class_id).count
      status_counts =
        AttendanceRecord.where(school_class_id: class_ids, date: today).group(:school_class_id, :status).count

      @today_stats = class_ids.each_with_object({}) do |class_id, memo|
        total = totals[class_id].to_i
        present = status_counts[[class_id, "present"]].to_i
        late = status_counts[[class_id, "late"]].to_i
        excused = status_counts[[class_id, "excused"]].to_i
        absent = status_counts[[class_id, "absent"]].to_i
        recorded = present + late + excused + absent
        missing = [total - recorded, 0].max
        rate =
          if total.zero?
            0
          else
            ((present + late + excused) * 100.0 / total).round
          end

        memo[class_id] = {
          total: total,
          present: present,
          late: late,
          excused: excused,
          absent: absent,
          missing: missing,
          rate: rate
        }
      end
    else
      @classes = @user.enrolled_classes.order(:name)
    end
  end
end
