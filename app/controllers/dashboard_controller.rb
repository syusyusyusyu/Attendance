class DashboardController < ApplicationController
  def show
    @user = current_user
    today = Time.zone.today
    if @user.staff?
      @classes = @user.manageable_classes.order(:name)
      class_ids = @classes.pluck(:id)

      totals = Enrollment.where(school_class_id: class_ids).group(:school_class_id).count
      status_counts =
        AttendanceRecord.where(school_class_id: class_ids, date: today).group(:school_class_id, :status).count

      @today_stats = class_ids.each_with_object({}) do |class_id, memo|
        total = totals[class_id].to_i
        present = status_counts[[class_id, "present"]].to_i
        late = status_counts[[class_id, "late"]].to_i
        excused = status_counts[[class_id, "excused"]].to_i
        early_leave = status_counts[[class_id, "early_leave"]].to_i
        absent = status_counts[[class_id, "absent"]].to_i
        recorded = present + late + excused + early_leave + absent
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
          early_leave: early_leave,
          absent: absent,
          missing: missing,
          rate: rate
        }
      end

      recent_range = 30.days.ago.to_date..today
      absents = AttendanceRecord
                .where(school_class_id: class_ids, date: recent_range, status: ["absent", "early_leave"])
                .group(:user_id)
                .count

      @attention_students = User.where(id: absents.keys).map do |student|
        { student: student, absences: absents[student.id].to_i }
      end.sort_by { |row| -row[:absences] }.first(5)

      @pending_requests = AttendanceRequest
                          .includes(:user, :school_class)
                          .where(school_class_id: class_ids, status: "pending")
                          .order(submitted_at: :desc)
                          .limit(5)

      @recent_notifications = current_user.notifications.order(created_at: :desc).limit(3)
    else
      @classes = @user.enrolled_classes.order(:name)
      recent_range = 30.days.ago.to_date..today
      records = @user.attendance_records.where(date: recent_range)
      total_by_class = records.group(:school_class_id).count
      present_by_class = records.where(status: "present").group(:school_class_id).count
      late_by_class = records.where(status: "late").group(:school_class_id).count
      excused_by_class = records.where(status: "excused").group(:school_class_id).count
      absent_by_class = records.where(status: "absent").group(:school_class_id).count
      early_leave_by_class = records.where(status: "early_leave").group(:school_class_id).count

      @student_summary = @classes.map do |klass|
        total = total_by_class[klass.id].to_i
        present = present_by_class[klass.id].to_i
        late = late_by_class[klass.id].to_i
        excused = excused_by_class[klass.id].to_i
        absent = absent_by_class[klass.id].to_i
        early_leave = early_leave_by_class[klass.id].to_i
        rate = total.zero? ? 0 : ((present + late + excused) * 100.0 / total).round

        {
          klass: klass,
          total: total,
          present: present,
          late: late,
          excused: excused,
          absent: absent,
          early_leave: early_leave,
          rate: rate,
          policy: klass.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
        }
      end

      @student_warnings = @student_summary.select do |row|
        policy = row[:policy]
        absence_count = row[:absent] + row[:early_leave]
        absence_count >= policy.warning_absent_count || row[:rate] < policy.warning_rate_percent
      end
      @recent_notifications = current_user.notifications.order(created_at: :desc).limit(3)
    end

    @today_sessions = @classes.each_with_object({}) do |klass, memo|
      result = ClassSessionResolver.new(school_class: klass, date: today).resolve
      memo[klass.id] = result&.dig(:session)
    end
  end
end
