require "csv"

class ClassAttendancesController < ApplicationController
  before_action -> { require_role!("teacher") }

  def show
    @classes = current_user.taught_classes.order(:name)
    @selected_class = @classes.find_by(id: params[:class_id])
    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    return unless @selected_class

    @policy = @selected_class.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
    @session_window = @selected_class.schedule_window(@date)
    @students = @selected_class.students.order(:name)
    @records = AttendanceRecord
               .where(school_class: @selected_class, date: @date)
               .index_by(&:user_id)
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def update
    selected_class = current_user.taught_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    reason = params[:reason].to_s.strip

    changes = []
    (params[:attendance] || {}).each do |user_id, status|
      record = AttendanceRecord.find_by(
        user_id: user_id,
        school_class: selected_class,
        date: date
      )
      next unless record&.persisted?

      previous_status = record.status
      changes << [user_id, previous_status, status] if previous_status != status
    end

    if changes.any? && reason.blank?
      redirect_to attendance_path(class_id: selected_class.id, date: date), alert: "修正理由を入力してください。" and return
    end

    (params[:attendance] || {}).each do |user_id, status|
      record = AttendanceRecord.find_or_initialize_by(
        user_id: user_id,
        school_class: selected_class,
        date: date
      )
      previous_status = record.status
      record.status = status
      record.verification_method = "manual"
      record.timestamp ||= Time.current
      record.modified_by = current_user
      record.modified_at = Time.current
      record.save!

      next if previous_status.nil? || previous_status == record.status

      AttendanceChange.create!(
        attendance_record: record,
        user: record.user,
        school_class: selected_class,
        date: date,
        previous_status: previous_status,
        new_status: record.status,
        reason: reason,
        modified_by: current_user,
        source: "manual",
        ip: request.remote_ip,
        user_agent: request.user_agent,
        changed_at: Time.current
      )

      Notification.create!(
        user: record.user,
        kind: "info",
        title: "出席状況が更新されました",
        body: "#{selected_class.name} (#{date.strftime('%Y-%m-%d')}) の出席が更新されました。",
        action_path: history_path(date: date)
      )
    end

    redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "出席を更新しました。"
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def export
    selected_class = current_user.taught_classes.find(params[:class_id])
    start_date = parse_date_param(params[:start_date]) || parse_date_param(params[:date]) || Date.current
    end_date = parse_date_param(params[:end_date]) || parse_date_param(params[:date]) || start_date

    if end_date < start_date
      start_date, end_date = end_date, start_date
    end

    students = selected_class.students.order(:name)
    records = AttendanceRecord
              .where(school_class: selected_class, date: start_date..end_date)
              .index_by { |record| [record.user_id, record.date] }

    dates = (start_date..end_date).to_a

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "日付",
        "クラス",
        "学生ID",
        "氏名",
        "出席状況",
        "記録時刻",
        "方法",
        "QRセッションID",
        "IP",
        "UserAgent",
        "備考"
      ]
      students.each do |student|
        dates.each do |date|
          record = records[[student.id, date]]
          location = record&.location || {}
          csv << [
            date.strftime("%Y-%m-%d"),
            selected_class.name,
            student.student_id,
            student.name,
            record&.status_label || "未入力",
            record&.timestamp&.strftime("%H:%M:%S"),
            record&.verification_method,
            location["qr_session_id"],
            location["ip"],
            location["user_agent"],
            record&.notes
          ]
        end
      end
    end

    filename = "attendance-#{selected_class.id}-#{start_date.strftime('%Y%m%d')}-#{end_date.strftime('%Y%m%d')}.csv"
    send_data "\uFEFF#{csv_data}", filename: filename, type: "text/csv; charset=utf-8"
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def import
    selected_class = current_user.taught_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    file = params[:csv_file]

    if file.blank?
      redirect_to attendance_path(class_id: selected_class.id, date: date), alert: "CSVファイルを選択してください。" and return
    end

    result = AttendanceCsvImporter.new(
      teacher: current_user,
      school_class: selected_class,
      csv_text: file.read
    ).import

    message = "インポート完了: 新規#{result[:created]}件 / 更新#{result[:updated]}件"
    message += " / スキップ#{result[:skipped]}件" if result[:skipped].positive?

    if result[:errors].any?
      errors = result[:errors].first(3).join(" ")
      message = "#{message} (エラー: #{errors})"
      redirect_to attendance_path(class_id: selected_class.id, date: date), alert: message
    else
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: message
    end
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def update_policy
    selected_class = current_user.taught_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    policy = selected_class.attendance_policy || selected_class.create_attendance_policy(AttendancePolicy.default_attributes)

    if policy.update(policy_params)
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "出席ポリシーを更新しました。"
    else
      redirect_to attendance_path(class_id: selected_class.id, date: date), alert: policy.errors.full_messages.join("、")
    end
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  private

  def parse_date_param(value)
    return nil if value.blank?

    Date.parse(value)
  end

  def policy_params
    params.require(:attendance_policy).permit(
      :late_after_minutes,
      :close_after_minutes,
      :allow_early_checkin,
      :allowed_ip_ranges,
      :allowed_user_agent_keywords,
      :max_scans_per_minute
    )
  end
end
