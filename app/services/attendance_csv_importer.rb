require "csv"

class AttendanceCsvImporter
  def initialize(teacher:, school_class:, csv_text:)
    @teacher = teacher
    @school_class = school_class
    @csv_text = csv_text
  end

  def import
    result = { created: 0, updated: 0, skipped: 0, errors: [] }

    sanitized_csv = @csv_text.to_s.sub(/\A\uFEFF/, "")

    CSV.parse(sanitized_csv, headers: true).each_with_index do |row, index|
      line_no = index + 2
      date_value = row["日付"] || row["date"] || row["Date"]
      student_id = row["学生ID"] || row["student_id"] || row["StudentID"]
      status_value = row["出席状況"] || row["status"] || row["Status"]
      notes = row["備考"] || row["notes"] || row["Notes"]

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

      status = normalize_status(status_value)
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
      was_new = record.new_record?
      previous_status = record.status

      record.status = status
      record.verification_method = "manual"
      record.timestamp ||= Time.current
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

  def normalize_status(value)
    text = value.to_s.strip
    return nil if text.blank?

    normalized = {
      "出席" => "present",
      "遅刻" => "late",
      "欠席" => "absent",
      "公欠" => "excused",
      "未入力" => :skip,
      "present" => "present",
      "late" => "late",
      "absent" => "absent",
      "excused" => "excused"
    }[text]

    normalized
  end
end
