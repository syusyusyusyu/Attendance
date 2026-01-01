class AttendanceCsvImporter < BaseCsvImporter
  def initialize(teacher:, school_class:, csv_text:)
    super(csv_text: csv_text)
    @teacher = teacher
    @school_class = school_class
    @sessions_cache = {}
  end

  def import
    result = { created: 0, updated: 0, skipped: 0, errors: [] }

    each_row do |row, line_no|
      date_value = cell_value(row, "日付", "date", "Date")
      student_id = cell_value(row, "学生ID", "student_id", "StudentID")
      status_value = cell_value(row, "出席状況", "status", "Status")
      notes = cell_value(row, "備考", "notes", "Notes")
      check_in_value = cell_value(row, "入室時刻", "入室", "check_in", "checked_in_at")
      check_out_value = cell_value(row, "退室時刻", "退室", "check_out", "checked_out_at")
      duration_value = cell_value(row, "滞在(分)", "滞在時間(分)", "duration_minutes", "duration")

      student_id = student_id.to_s.strip

      if date_value.blank? || student_id.blank? || status_value.blank?
        result[:errors] << "行#{line_no}: 必須項目が不足しています。"
        next
      end

      date = parse_date(date_value)
      unless date
        result[:errors] << "行#{line_no}: 日付が不正です。"
        next
      end

      status = AttendanceRecord.normalize_status(status_value)
      if status == :skip
        result[:skipped] += 1
        next
      end

      unless status
        result[:errors] << "行#{line_no}: 出席状況が不正です。"
        next
      end

      student = @school_class.students.find_by(student_id: student_id)
      unless student
        result[:errors] << "行#{line_no}: 学生IDが見つかりません。"
        next
      end

      record = AttendanceRecord.find_or_initialize_by(
        user: student,
        school_class: @school_class,
        date: date
      )
      record.class_session ||= session_for(date)
      was_new = record.new_record?
      previous_status = record.status

      record.status = status
      record.verification_method = "manual"
      record.checked_in_at = parse_time(date, check_in_value) if check_in_value.present?
      record.checked_out_at = parse_time(date, check_out_value) if check_out_value.present?
      record.duration_minutes = parse_integer(duration_value) if duration_value.present?
      record.timestamp ||= record.checked_in_at || Time.current
      record.notes = notes if notes.present?
      record.modified_by = @teacher
      record.modified_at = Time.current

      if record.save
        was_new ? result[:created] += 1 : result[:updated] += 1

        if previous_status.present? && previous_status != record.status
          AttendanceChange.create!(
            attendance_record: record,
            user: student,
            school_class: @school_class,
            date: date,
            previous_status: previous_status,
            new_status: record.status,
            reason: notes.presence || "CSVインポート",
            modified_by: @teacher,
            source: "csv",
            changed_at: Time.current
          )

          Notification.create!(
            user: student,
            kind: "info",
            title: "出席状況が更新されました",
            body: "#{@school_class.name} (#{date.strftime('%Y-%m-%d')}) の出席が更新されました。",
            action_path: Rails.application.routes.url_helpers.history_path(date: date)
          )
        end
      else
        result[:errors] << "行#{line_no}: #{record.errors.full_messages.join("、")}"
      end
    end

    result
  end

  private

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def session_for(date)
    @sessions_cache[date] ||= ClassSessionResolver.new(school_class: @school_class, date: date)&.resolve&.dig(:session)
  end

  def parse_time(date, value)
    return nil if value.blank?

    Time.zone.parse("#{date} #{value}")
  rescue ArgumentError
    nil
  end

  def parse_integer(value)
    Integer(value.to_s.strip, 10)
  rescue ArgumentError, TypeError
    nil
  end
end
