require "csv"

class AttendanceHistoryController < ApplicationController
  before_action -> { require_role!("student") }
  before_action -> { require_permission!("history.view") }
  before_action -> { require_permission!("history.export") }, only: [:export]

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
      elsif statuses.include?("early_leave") || statuses.include?("late")
        "late"
      elsif statuses.include?("excused")
        "excused"
      else
        "present"
      end
    end

    @records = current_user.attendance_records
                           .includes(:school_class, :class_session)
                           .where(date: @date)
                           .order(:timestamp)

    @requests_by_class = current_user.attendance_requests
                                     .where(date: @date)
                                     .index_by(&:school_class_id)

    record_ids = @records.map(&:id)
    @changes_by_record = AttendanceChange
                         .where(attendance_record_id: record_ids)
                         .order(changed_at: :desc)
                         .group_by(&:attendance_record_id)
                         .transform_values { |items| items.first }
    @policies_by_class = SchoolClass
                         .where(id: @records.map(&:school_class_id))
                         .includes(:attendance_policy)
                         .index_by(&:id)
  rescue ArgumentError
    redirect_to history_path, alert: "日付の形式が正しくありません。"
  end

  def export
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : Date.current.beginning_of_month
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current.end_of_month
    end_date = start_date if end_date < start_date

    records = current_user.attendance_records
                          .includes(:school_class, :class_session)
                          .where(date: start_date..end_date)
                          .order(:date, :timestamp)

    requests = current_user.attendance_requests.where(date: start_date..end_date)
    requests_by_key = requests.index_by { |request| [request.school_class_id, request.date] }

    change_map = AttendanceChange
                 .where(attendance_record_id: records.map(&:id))
                 .order(changed_at: :desc)
                 .group_by(&:attendance_record_id)
                 .transform_values { |items| items.first }

    respond_to do |format|
      format.html do
        redirect_to history_path, alert: "出力形式を選択してください。"
      end
      format.csv do
        csv_data = history_csv(records, requests_by_key, change_map)
        send_data "\uFEFF#{csv_data}",
                  filename: history_filename(start_date, end_date, "csv"),
                  type: "text/csv; charset=utf-8"
      end
      format.pdf do
        send_data history_pdf(records, requests_by_key, change_map, start_date, end_date),
                  filename: history_filename(start_date, end_date, "pdf"),
                  type: "application/pdf"
      end
    end
  rescue ArgumentError
    redirect_to history_path, alert: "日付の形式が正しくありません。"
  end

  private

  def history_filename(start_date, end_date, ext)
    "attendance-history-#{current_user.id}-#{start_date.strftime('%Y%m%d')}-#{end_date.strftime('%Y%m%d')}.#{ext}"
  end

  def history_csv(records, requests_by_key, change_map)
    CSV.generate(headers: true) do |csv|
      csv << ["日付", "クラス", "出席状況", "入室", "退室", "滞在(分)", "申請", "更新理由"]
      records.each do |record|
        request = requests_by_key[[record.school_class_id, record.date]]
        change = change_map[record.id]
        csv << [
          record.date.strftime("%Y-%m-%d"),
          record.school_class&.name,
          record.status_label || record.status,
          record.checked_in_at&.strftime("%H:%M"),
          record.checked_out_at&.strftime("%H:%M"),
          record.duration_minutes,
          request_label(request),
          change&.reason
        ]
      end
    end
  end

  def history_pdf(records, requests_by_key, change_map, start_date, end_date)
    require "prawn"
    pdf = Prawn::Document.new(page_size: "A4", margin: [36, 36, 36, 36])
    pdf.text "個人出席履歴", size: 16, style: :bold
    pdf.move_down 4
    pdf.text "#{current_user.name} / #{start_date.strftime('%Y-%m-%d')} - #{end_date.strftime('%Y-%m-%d')}", size: 10
    pdf.move_down 6
    pdf.text "対象件数: #{records.size}", size: 10
    pdf.move_down 10

    headers = ["日付", "クラス", "出席状況", "入室", "退室", "滞在(分)", "申請", "更新理由"]
    rows = records.map do |record|
      request = requests_by_key[[record.school_class_id, record.date]]
      change = change_map[record.id]
      [
        record.date.strftime("%Y-%m-%d"),
        record.school_class&.name,
        record.status_label || record.status,
        record.checked_in_at&.strftime("%H:%M"),
        record.checked_out_at&.strftime("%H:%M"),
        record.duration_minutes.to_s,
        request_label(request),
        change&.reason.to_s
      ]
    end

    column_sizes = [10, 12, 8, 5, 5, 7, 10, 16]
    format_row = lambda do |row|
      row.zip(column_sizes).map do |value, size|
        value.to_s.ljust(size)[0, size]
      end.join(" ")
    end

    pdf.move_down 4
    pdf.font("Courier") do
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

  def request_label(request)
    return "-" unless request

    status_labels = { "pending" => "審査中", "approved" => "承認", "rejected" => "却下" }
    type_labels = { "absent" => "欠席", "late" => "遅刻", "excused" => "公欠" }
    status = status_labels[request.status] || request.status
    type = type_labels[request.request_type] || request.request_type
    "#{status}(#{type})"
  end
end
