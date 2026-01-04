class TermReportBuilder
  def initialize(school_class:, start_date:, end_date:)
    @school_class = school_class
    @start_date = start_date
    @end_date = end_date
    @policy = school_class.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
  end

  def build
    session_dates = sessions_in_range
    records = AttendanceRecord
              .where(school_class: @school_class, date: @start_date..@end_date)
              .to_a
    records_by_student = records.group_by(&:user_id)

    students = @school_class.students.order(:name)

    student_rows = students.map do |student|
      records_map = (records_by_student[student.id] || []).index_by(&:date)
      counts = Hash.new(0)

      session_dates.each do |date|
        record = records_map[date]
        if record
          counts[record.status.to_sym] += 1
        else
          counts[:missing] += 1
        end
      end

      expected = session_dates.size
      rate = @policy.attendance_rate(
        present: counts[:present],
        late: counts[:late],
        excused: counts[:excused],
        expected: expected
      )
      absence_total = counts[:absent].to_i + counts[:early_leave].to_i + counts[:missing].to_i

      {
        student: student,
        rate: rate,
        present: counts[:present].to_i,
        late: counts[:late].to_i,
        excused: counts[:excused].to_i,
        early_leave: counts[:early_leave].to_i,
        absent: counts[:absent].to_i,
        missing: counts[:missing].to_i,
        alert_label: @policy.warning_label(absence_total: absence_total, attendance_rate: rate)
      }
    end

    {
      school_class: @school_class,
      start_date: @start_date,
      end_date: @end_date,
      sessions_count: session_dates.size,
      students: student_rows
    }
  end

  private

  def sessions_in_range
    (@start_date..@end_date).each_with_object([]) do |date, memo|
      result = ClassSessionResolver.new(school_class: @school_class, date: date).resolve
      session = result&.dig(:session)
      next if session.blank? || session.status_canceled?

      memo << date
    end
  end
end
