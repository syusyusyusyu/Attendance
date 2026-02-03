class DashboardController < ApplicationController
  def show
    @user = current_user
    @show_onboarding = session.delete(:show_onboarding)
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
        @overall_total ||= 0
        @overall_present_equiv ||= 0
        @overall_total += total
        @overall_present_equiv += present + late + excused
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

      @staff_attendance_rate =
        if @overall_total.to_i.zero?
          0
        else
          ((@overall_present_equiv.to_i * 100.0) / @overall_total.to_i).round
        end

      yesterday = today - 1.day
      yesterday_status_counts =
        AttendanceRecord.where(school_class_id: class_ids, date: yesterday).group(:status).count
      yesterday_present_equiv =
        yesterday_status_counts.fetch("present", 0).to_i +
        yesterday_status_counts.fetch("late", 0).to_i +
        yesterday_status_counts.fetch("excused", 0).to_i
      yesterday_rate =
        if @overall_total.to_i.zero?
          0
        else
          ((yesterday_present_equiv * 100.0) / @overall_total.to_i).round
        end
      @staff_attendance_diff = (@staff_attendance_rate - yesterday_rate).round(1)
      @pending_requests_today =
        AttendanceRequest
          .where(school_class_id: class_ids, status: "pending", submitted_at: today.all_day)
          .count

      trend_range = 29.days.ago.to_date..today
      trend_counts =
        AttendanceRecord
          .where(school_class_id: class_ids, date: trend_range)
          .group(:date, :status)
          .count
      @staff_daily_rates = trend_range.map do |date|
        present_equiv =
          trend_counts.fetch([date, "present"], 0).to_i +
          trend_counts.fetch([date, "late"], 0).to_i +
          trend_counts.fetch([date, "excused"], 0).to_i
        total =
          trend_counts.fetch([date, "present"], 0).to_i +
          trend_counts.fetch([date, "late"], 0).to_i +
          trend_counts.fetch([date, "excused"], 0).to_i +
          trend_counts.fetch([date, "early_leave"], 0).to_i +
          trend_counts.fetch([date, "absent"], 0).to_i
        rate =
          if total.zero?
            0
          else
            ((present_equiv * 100.0) / total).round
          end
        { date: date, rate: rate }
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
        policy = klass.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
        rate = policy.attendance_rate(
          present: present,
          late: late,
          excused: excused,
          expected: total
        )

        {
          klass: klass,
          total: total,
          present: present,
          late: late,
          excused: excused,
          absent: absent,
          early_leave: early_leave,
          rate: rate,
          policy: policy
        }
      end

      total_expected = @student_summary.sum { |row| row[:total].to_i }
      present_equiv = @student_summary.sum { |row| row[:present].to_i + row[:late].to_i + row[:excused].to_i }
      @student_attendance_rate =
        if total_expected.zero?
          0
        else
          ((present_equiv * 100.0) / total_expected).round
        end

      prev_range = 60.days.ago.to_date..31.days.ago.to_date
      prev_records = @user.attendance_records.where(date: prev_range)
      prev_total = prev_records.count
      prev_present_equiv = prev_records.where(status: ["present", "late", "excused"]).count
      prev_rate =
        if prev_total.zero?
          0
        else
          ((prev_present_equiv * 100.0) / prev_total).round
        end
      @student_attendance_diff = (@student_attendance_rate - prev_rate).round(1)
      @student_pending_today =
        @user.attendance_requests.where(status: "pending", submitted_at: today.all_day).count

      @student_warnings = @student_summary.select do |row|
        policy = row[:policy]
        absence_count = row[:absent] + row[:early_leave]
        policy.warning?(absence_total: absence_count, attendance_rate: row[:rate])
      end
      @recent_notifications = current_user.notifications.order(created_at: :desc).limit(3)
    end

    @today_sessions = @classes.each_with_object({}) do |klass, memo|
      result = ClassSessionResolver.new(school_class: klass, date: today).resolve
      memo[klass.id] = result&.dig(:session)
    end

    @today_classes = @user.staff? ? @classes.select { |klass| @today_sessions[klass.id].present? } : []
  end
end
