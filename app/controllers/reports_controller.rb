require "csv"

class ReportsController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("reports.view") }

  def index
    @classes = current_user.manageable_classes.includes(:students, :attendance_policy).order(:name)
    selected_class_id =
      if params.key?(:class_id)
        params[:class_id].presence
      else
        session[:reports_class_id]
      end
    selected_class_id = @classes.first.id if selected_class_id.blank? && @classes.one? && request.format.html?
    @selected_class = selected_class_id.present? ? @classes.find { |klass| klass.id == selected_class_id.to_i } : nil

    if params.key?(:class_id)
      if @selected_class
        session[:reports_class_id] = @selected_class.id
      else
        session.delete(:reports_class_id)
      end
    elsif @selected_class
      session[:reports_class_id] ||= @selected_class.id
    elsif selected_class_id.present?
      session.delete(:reports_class_id)
    end

    @start_date =
      if params[:start_date].present?
        Date.parse(params[:start_date])
      else
        safe_date_from(session[:reports_start_date]) || 30.days.ago.to_date
      end
    @end_date =
      if params[:end_date].present?
        Date.parse(params[:end_date])
      else
        safe_date_from(session[:reports_end_date]) || Date.current
      end
    session[:reports_start_date] = @start_date.to_s
    session[:reports_end_date] = @end_date.to_s
    if @end_date < @start_date
      @start_date, @end_date = @end_date, @start_date
    end

    if request.format.csv? || request.format.pdf?
      export_term_report and return
    end

    class_ids = @classes.map(&:id)
    records = AttendanceRecord
              .includes(:user)
              .where(school_class_id: class_ids, date: @start_date..@end_date)
              .to_a

    records_by_class_date = records.group_by { |record| [record.school_class_id, record.date] }

    @class_stats = @classes.map do |klass|
      policy = klass.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
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
      rate = policy.attendance_rate(
        present: totals[:present],
        late: totals[:late],
        excused: totals[:excused],
        expected: expected
      )

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

    build_class_detail(@selected_class, records, @start_date, @end_date) if @selected_class
  rescue ArgumentError
    redirect_to reports_path, alert: "日付の形式が正しくありません。"
  end

  private

  def export_term_report
    require_permission!("reports.export")

    unless @selected_class
      redirect_to reports_path, alert: "クラスを選択してください。" and return
    end

    report = TermReportBuilder.new(
      school_class: @selected_class,
      start_date: @start_date,
      end_date: @end_date
    ).build

    respond_to do |format|
      format.csv do
        csv_data = term_report_csv(report)
        send_data "\uFEFF#{csv_data}",
                  filename: term_report_filename(report, "csv"),
                  type: "text/csv; charset=utf-8"
      end
      format.pdf do
        send_data term_report_pdf(report),
                  filename: term_report_filename(report, "pdf"),
                  type: "application/pdf"
      end
    end
  end

  def term_report_filename(report, ext)
    "term-report-#{report[:school_class].id}-#{report[:start_date].strftime('%Y%m%d')}-#{report[:end_date].strftime('%Y%m%d')}.#{ext}"
  end

  def term_report_csv(report)
    CSV.generate(headers: true) do |csv|
      csv << ["学生ID", "氏名", "出席率(%)", "出席", "遅刻", "公欠", "早退", "欠席", "未入力", "判定"]
      report[:students].each do |row|
        csv << [
          row[:student].student_id,
          row[:student].name,
          row[:rate],
          row[:present],
          row[:late],
          row[:excused],
          row[:early_leave],
          row[:absent],
          row[:missing],
          row[:alert_label]
        ]
      end
    end
  end

  def term_report_pdf(report)
    require "prawn"

    pdf = Prawn::Document.new(page_size: "A4", margin: [36, 36, 36, 36])
    font_name = apply_japanese_font(pdf)
    pdf.text "期末出席レポート", size: 16, style: :bold
    pdf.move_down 4
    pdf.text "#{report[:school_class].name} / #{report[:start_date].strftime('%Y-%m-%d')} - #{report[:end_date].strftime('%Y-%m-%d')}"
    pdf.move_down 6
    pdf.text "対象授業回数: #{report[:sessions_count]}", size: 10

    students = report[:students]
    avg_rate =
      if students.any?
        (students.sum { |row| row[:rate].to_f } / students.size).round(1)
      else
        0
      end

    totals = students.each_with_object(Hash.new(0)) do |row, memo|
      memo[:present] += row[:present].to_i
      memo[:late] += row[:late].to_i
      memo[:excused] += row[:excused].to_i
      memo[:early_leave] += row[:early_leave].to_i
      memo[:absent] += row[:absent].to_i
      memo[:missing] += row[:missing].to_i
    end

    pdf.text "対象学生数: #{students.size} / 平均出席率: #{avg_rate}%", size: 10
    pdf.move_down 10

    status_labels = {
      present: "出席",
      late: "遅刻",
      excused: "公欠",
      early_leave: "早退",
      absent: "欠席",
      missing: "未入力"
    }
    status_colors = {
      present: "34A853",
      late: "FBBF24",
      excused: "60A5FA",
      early_leave: "FB923C",
      absent: "F87171",
      missing: "9CA3AF"
    }

    pdf.text "集計グラフ", size: 11, style: :bold
    pdf.move_down 6
    max_value = totals.values.max.to_i
    bar_width = 240
    bar_height = 10

    status_labels.each do |key, label|
      value = totals[key].to_i
      width = max_value.zero? ? 0 : (value.to_f / max_value) * bar_width
      y = pdf.cursor
      pdf.fill_color status_colors[key]
      pdf.fill_rectangle [pdf.bounds.left, y], width, bar_height
      pdf.fill_color "000000"
      pdf.text_box "#{label} #{value}", at: [pdf.bounds.left + bar_width + 8, y - 1], size: 9, width: 120, height: bar_height
      pdf.move_down bar_height + 6
    end

    pdf.move_down 6
    headers = ["学生ID", "氏名", "出席率", "出席", "遅刻", "公欠", "早退", "欠席", "未入力", "判定"]
    rows = students.map do |row|
      [
        row[:student].student_id,
        row[:student].name,
        "#{row[:rate]}%",
        row[:present],
        row[:late],
        row[:excused],
        row[:early_leave],
        row[:absent],
        row[:missing],
        row[:alert_label]
      ]
    end

    column_sizes = [10, 12, 6, 5, 5, 5, 5, 5, 6, 6]
    format_row = lambda do |row|
      row.zip(column_sizes).map do |value, size|
        value.to_s.ljust(size)[0, size]
      end.join(" ")
    end

    pdf.move_down 4
    pdf.font(font_name) do
      pdf.font_size 8
      pdf.text format_row.call(headers)
      pdf.stroke_horizontal_rule
      pdf.move_down 4
      rows.each do |row|
        pdf.text format_row.call(row)
      end
    end

    pdf.render
  end

  def apply_japanese_font(pdf)
    font_path = Rails.root.join("app/assets/fonts/NotoSansJP-Regular.ttf")
    bold_path = Rails.root.join("app/assets/fonts/NotoSansJP-Bold.ttf")
    font_name = "NotoSansJP"

    if File.exist?(font_path)
      pdf.font_families.update(
        font_name => {
          normal: font_path.to_s,
          bold: File.exist?(bold_path) ? bold_path.to_s : font_path.to_s
        }
      )
      pdf.font(font_name)
      font_name
    else
      pdf.font("Helvetica")
      "Helvetica"
    end
  end

  def safe_date_from(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def build_class_detail(selected_class, records, start_date, end_date)
    policy = selected_class.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
    sessions = sessions_by_date(selected_class, start_date, end_date)
    session_dates = sessions.map(&:first)
    total_students = selected_class.students.size

    class_records = records.select { |record| record.school_class_id == selected_class.id }
    records_by_date = class_records.group_by(&:date)
    records_by_student = class_records.group_by(&:user_id)

    @daily_rates = sessions.map do |date, session|
      daily = records_by_date[date] || []
      counts = daily.group_by(&:status).transform_values(&:count)
      expected = total_students
      rate = policy.attendance_rate(
        present: counts["present"],
        late: counts["late"],
        excused: counts["excused"],
        expected: expected
      )

      {
        date: date,
        session: session,
        counts: {
          present: counts["present"].to_i,
          late: counts["late"].to_i,
          excused: counts["excused"].to_i,
          early_leave: counts["early_leave"].to_i,
          absent: counts["absent"].to_i
        },
        missing: [expected - daily.size, 0].max,
        rate: rate
      }
    end

    @weekly_rates = build_weekly_rates(@daily_rates, total_students, policy)
    @student_stats = build_student_stats(selected_class, records_by_student, session_dates, policy)
    @risk_students = @student_stats.select { |row| row[:alert] }

    sessions_by_week = session_dates.group_by { |date| date.beginning_of_week(:monday) }
    @weekly_keys = sessions_by_week.keys.sort.last(4)
    @student_trends = build_student_trends(@student_stats, records_by_student, sessions_by_week, @weekly_keys, policy)

    @reason_distribution = build_reason_distribution(selected_class, class_records, start_date, end_date)
  end

  def sessions_by_date(school_class, start_date, end_date)
    (start_date..end_date).each_with_object([]) do |date, memo|
      result = ClassSessionResolver.new(school_class: school_class, date: date).resolve
      session = result&.dig(:session)
      next if session.blank? || session.status_canceled?

      memo << [date, session]
    end
  end

  def build_weekly_rates(daily_rates, total_students, policy)
    grouped = daily_rates.group_by { |row| row[:date].beginning_of_week(:monday) }
    grouped.map do |week_start, rows|
      totals = { present: 0, late: 0, excused: 0, early_leave: 0, absent: 0, missing: 0 }
      rows.each do |row|
        totals[:present] += row[:counts][:present]
        totals[:late] += row[:counts][:late]
        totals[:excused] += row[:counts][:excused]
        totals[:early_leave] += row[:counts][:early_leave]
        totals[:absent] += row[:counts][:absent]
        totals[:missing] += row[:missing]
      end
      expected = total_students * rows.size
      rate = policy.attendance_rate(
        present: totals[:present],
        late: totals[:late],
        excused: totals[:excused],
        expected: expected
      )

      {
        week_start: week_start,
        week_end: week_start + 6.days,
        rate: rate,
        totals: totals,
        sessions_count: rows.size
      }
    end.sort_by { |row| row[:week_start] }
  end

  def build_student_stats(selected_class, records_by_student, session_dates, policy)
    selected_class.students.order(:name).map do |student|
      records_map = (records_by_student[student.id] || []).index_by(&:date)
      counts = { present: 0, late: 0, excused: 0, early_leave: 0, absent: 0, missing: 0 }

      session_dates.each do |date|
        record = records_map[date]
        if record
          counts[record.status.to_sym] += 1
        else
          counts[:missing] += 1
        end
      end

      expected = session_dates.size
      rate = policy.attendance_rate(
        present: counts[:present],
        late: counts[:late],
        excused: counts[:excused],
        expected: expected
      )
      absence_total = counts[:absent] + counts[:early_leave] + counts[:missing]
      alert = policy.warning?(absence_total: absence_total, attendance_rate: rate)

      {
        student: student,
        rate: rate,
        present: counts[:present],
        late: counts[:late],
        excused: counts[:excused],
        early_leave: counts[:early_leave],
        absent: counts[:absent],
        missing: counts[:missing],
        absence_total: absence_total,
        expected: expected,
        alert: alert,
        alert_label: policy.warning_label(absence_total: absence_total, attendance_rate: rate)
      }
    end
  end

  def build_student_trends(student_stats, records_by_student, sessions_by_week, week_keys, policy)
    student_stats.map do |row|
      records_map = (records_by_student[row[:student].id] || []).index_by(&:date)
      weekly_rates = week_keys.map do |week_start|
        dates = sessions_by_week[week_start] || []
        expected = dates.size
        counts = { present: 0, late: 0, excused: 0 }

        dates.each do |date|
          record = records_map[date]
          next unless record

          case record.status
          when "present"
            counts[:present] += 1
          when "late"
            counts[:late] += 1
          when "excused"
            counts[:excused] += 1
          end
        end

        rate = policy.attendance_rate(
          present: counts[:present],
          late: counts[:late],
          excused: counts[:excused],
          expected: expected
        )
        { week_start: week_start, rate: rate }
      end

      row.merge(weekly_rates: weekly_rates)
    end
  end

  def build_reason_distribution(selected_class, class_records, start_date, end_date)
    requests = AttendanceRequest
               .where(school_class: selected_class, date: start_date..end_date)
               .order(processed_at: :desc, submitted_at: :desc)

    requests_by_key = {}
    requests.each do |request|
      key = [request.user_id, request.date, request.request_type]
      requests_by_key[key] ||= request
    end

    changes_by_record = AttendanceChange
                        .where(attendance_record_id: class_records.map(&:id))
                        .order(changed_at: :desc)
                        .group_by(&:attendance_record_id)
                        .transform_values { |items| items.first }

    distribution = { "late" => Hash.new(0), "early_leave" => Hash.new(0) }
    ignore_reasons = ["QRスキャン", "QR退室", "出席確定(自動欠席)", "出席確定(申請反映)"]

    class_records.each do |record|
      next unless record.status_late? || record.status_early_leave?

      default_reason = record.status_early_leave? ? "滞在時間不足" : "自動判定"
      reason = nil

      if record.status_late?
        request = requests_by_key[[record.user_id, record.date, "late"]]
        reason = request&.reason
      end

      if reason.blank?
        change = changes_by_record[record.id]
        reason = change&.reason unless ignore_reasons.include?(change&.reason)
      end

      reason = default_reason if reason.blank?
      distribution[record.status][reason] += 1
    end

    distribution.transform_values { |reasons| reasons.sort_by { |_, count| -count }.to_h }
  end
end
