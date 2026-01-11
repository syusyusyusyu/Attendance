require "csv"

class ClassAttendancesController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("attendance.manage") }, only: [:show, :update, :export]
  before_action -> { require_permission!("attendance.import") }, only: [:import]
  before_action -> { require_permission!("attendance.policy.manage") }, only: [:update_policy]
  before_action -> { require_permission!("attendance.finalize") }, only: [:finalize]
  before_action -> { require_permission!("attendance.unlock") }, only: [:unlock]

  def show
    @classes = current_user.manageable_classes.order(:name)
    selected_class_id =
      if params.key?(:class_id)
        params[:class_id].presence
      else
        session[:attendance_class_id]
      end
    selected_class_id = @classes.first.id if selected_class_id.blank? && @classes.one?
    @selected_class = @classes.find_by(id: selected_class_id)

    if params.key?(:class_id)
      if @selected_class
        session[:attendance_class_id] = @selected_class.id
      else
        session.delete(:attendance_class_id)
      end
    elsif @selected_class
      session[:attendance_class_id] ||= @selected_class.id
    elsif selected_class_id.present?
      session.delete(:attendance_class_id)
    end

    @date =
      if params[:date].present?
        Date.parse(params[:date])
      else
        safe_date_from(session[:attendance_date]) || Date.current
      end
    session[:attendance_date] = @date.to_s

    return unless @selected_class

    @policy = @selected_class.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)
    @session_window = @selected_class.schedule_window(@date)
    @class_session = @session_window&.dig(:class_session)

    if @class_session
      AttendanceRecord
        .where(school_class: @selected_class, date: @date, class_session_id: nil)
        .update_all(class_session_id: @class_session.id)
    end

    @students = @selected_class.students.order(:name)
    @records = AttendanceRecord
               .where(school_class: @selected_class, date: @date)
               .index_by(&:user_id)
    @pending_requests = AttendanceRequest
                        .where(school_class: @selected_class, date: @date, status: "pending")
                        .index_by(&:user_id)

    @finalize_available = false
    if @class_session&.start_at.present? && !@class_session.locked?
      close_at = @class_session.start_at + @policy.close_after_minutes.minutes
      @finalize_available = Time.current >= close_at
    end
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def update
    selected_class = current_user.manageable_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    reason = params[:reason].to_s.strip

    window = selected_class.schedule_window(date)
    class_session = window&.dig(:class_session)

    if class_session&.locked? && !current_user.admin?
      redirect_to attendance_path(class_id: selected_class.id, date: date),
                  alert: "出席が確定済みのため修正できません。" and return
    end

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
      redirect_to attendance_path(class_id: selected_class.id, date: date),
                  alert: "修正理由を入力してください。" and return
    end

    if changes.any? && !current_user.admin?
      create_operation_request!(
        kind: "attendance_correction",
        school_class: selected_class,
        reason: reason,
        payload: {
          "date" => date.to_s,
          "changes" => changes.map { |user_id, _previous, status| { "user_id" => user_id, "status" => status } }
        }
      )
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "修正内容を承認申請しました。"
      return
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
      record.class_session ||= class_session if class_session
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
    selected_class = current_user.manageable_classes.find(params[:class_id])
    start_date = parse_date_param(params[:start_date]) || parse_date_param(params[:date]) || Date.current
    end_date = parse_date_param(params[:end_date]) || parse_date_param(params[:date]) || start_date

    if end_date < start_date
      start_date, end_date = end_date, start_date
    end

    students = selected_class.students.order(:name)
    records = AttendanceRecord
              .where(school_class: selected_class, date: start_date..end_date)
              .index_by { |record| [record.user_id, record.date] }
    requests = AttendanceRequest
               .where(school_class: selected_class, date: start_date..end_date)
               .order(submitted_at: :desc)
    requests_by_key = {}
    requests.each do |request|
      key = [request.user_id, request.date]
      requests_by_key[key] ||= request
    end

    dates = (start_date..end_date).to_a

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "日付",
        "授業回ID",
        "クラス",
        "学生ID",
        "氏名",
        "出席状況",
        "入室時刻",
        "退室時刻",
        "滞在(分)",
        "方法",
        "QRセッションID",
        "IP",
        "UserAgent",
        "備考",
        "申請状況",
        "申請種別",
        "申請理由"
      ]
      students.each do |student|
        dates.each do |date|
          record = records[[student.id, date]]
          location = record&.location || {}
          request = requests_by_key[[student.id, date]]
          session_id = record&.class_session_id
          csv << [
            date.strftime("%Y-%m-%d"),
            session_id,
            selected_class.name,
            student.student_id,
            student.name,
            record&.status_label || "未入力",
            record&.checked_in_at&.strftime("%H:%M:%S"),
            record&.checked_out_at&.strftime("%H:%M:%S"),
            record&.duration_minutes,
            record&.verification_method,
            location["qr_session_id"],
            location["ip"],
            location["user_agent"],
            record&.notes,
            request&.status,
            request&.request_type,
            request&.reason
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
    selected_class = current_user.manageable_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    file = params[:csv_file]

    if file.blank?
      redirect_to attendance_path(class_id: selected_class.id, date: date),
                  alert: "CSVファイルを選択してください。" and return
    end

    unless current_user.admin?
      create_operation_request!(
        kind: "attendance_csv_import",
        school_class: selected_class,
        reason: "CSVインポート申請",
        payload: {
          "date" => date.to_s,
          "filename" => file.original_filename,
          "csv_text" => file.read
        }
      )
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "CSVインポートを承認申請しました。"
      return
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
    selected_class = current_user.manageable_classes.find(params[:class_id])
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

  def finalize
    selected_class = current_user.manageable_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    window = selected_class.schedule_window(date)
    class_session = window&.dig(:class_session)
    policy = selected_class.attendance_policy || AttendancePolicy.new(AttendancePolicy.default_attributes)

    if class_session.blank?
      redirect_to attendance_path(class_id: selected_class.id, date: date), alert: "授業回が見つかりません。" and return
    end

    if class_session.locked?
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "すでに確定済みです。" and return
    end

    if class_session.start_at.present?
      close_at = class_session.start_at + policy.close_after_minutes.minutes
      if Time.current < close_at
        redirect_to attendance_path(class_id: selected_class.id, date: date),
                    alert: "授業締切のため確定できません。" and return
      end
    end

    unless current_user.admin?
      create_operation_request!(
        kind: "attendance_finalize",
        school_class: selected_class,
        reason: "出席確定申請",
        payload: {
          "date" => date.to_s,
          "class_session_id" => class_session.id
        }
      )
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "出席確定を承認申請しました。"
      return
    end

    AttendanceFinalizer.new(class_session: class_session, policy: policy).finalize!(
      class_session.start_at.present? ? class_session.start_at + policy.close_after_minutes.minutes : Time.current
    )
    redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "出席を確定しました。"
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  def unlock
    selected_class = current_user.manageable_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current
    window = selected_class.schedule_window(date)
    class_session = window&.dig(:class_session)

    if class_session.blank?
      redirect_to attendance_path(class_id: selected_class.id, date: date), alert: "授業回が見つかりません。" and return
    end

    unless current_user.admin?
      create_operation_request!(
        kind: "attendance_unlock",
        school_class: selected_class,
        reason: "確定解除申請",
        payload: {
          "date" => date.to_s,
          "class_session_id" => class_session.id
        }
      )
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "確定解除を承認申請しました。"
      return
    end

    unless class_session.locked?
      redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "未確定のため解除不要です。" and return
    end

    class_session.update!(locked_at: nil)
    redirect_to attendance_path(class_id: selected_class.id, date: date), notice: "出席確定を解除しました。"
  rescue ArgumentError
    redirect_to attendance_path, alert: "日付の形式が正しくありません。"
  end

  private

  def parse_date_param(value)
    return nil if value.blank?

    Date.parse(value)
  end

  def safe_date_from(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def policy_params
    permitted = params.require(:attendance_policy).permit(
      :late_after_minutes,
      :close_after_minutes,
      :allow_early_checkin,
      :allowed_ip_ranges,
      :allowed_user_agent_keywords,
      :max_scans_per_minute,
      :student_max_scans_per_minute,
      :minimum_attendance_rate,
      :warning_absent_count,
      :warning_rate_percent,
      :require_registered_device,
      :require_location,
      :geo_fence_enabled,
      :geo_center_lat,
      :geo_center_lng,
      :geo_radius_m,
      :geo_accuracy_max_m,
      :fraud_failure_threshold,
      :fraud_ip_burst_threshold,
      :fraud_token_share_threshold
    )
    permitted.merge(
      late_after_minutes: AttendancePolicy::DEFAULTS[:late_after_minutes],
      close_after_minutes: AttendancePolicy::DEFAULTS[:close_after_minutes]
    )
  end

  def create_operation_request!(kind:, school_class:, reason:, payload:)
    kind_labels = {
      "attendance_correction" => "出席修正",
      "attendance_finalize" => "出席確定",
      "attendance_unlock" => "確定解除",
      "attendance_csv_import" => "CSV反映"
    }

    OperationRequest.create!(
      user: current_user,
      school_class: school_class,
      kind: kind,
      reason: reason,
      payload: payload,
      status: "pending"
    )

    User.where(role: "admin").find_each do |admin|
      Notification.create!(
        user: admin,
        kind: "warning",
        title: "操作申請が届きました",
        body: "#{current_user.name} から#{kind_labels[kind] || kind}の申請があります。",
        action_path: admin_operation_requests_path(status: "pending")
      )
    end
  end
end
