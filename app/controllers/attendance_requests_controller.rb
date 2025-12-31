class AttendanceRequestsController < ApplicationController
  before_action :load_request, only: [:update]

  def index
    if current_user.staff?
      @classes = current_user.manageable_classes.order(:name)
      @selected_class = @classes.find_by(id: params[:class_id])
      @status = params[:status].presence

      scope = AttendanceRequest.includes(:user, :school_class, :class_session).order(submitted_at: :desc)
      scope = scope.where(school_class: @selected_class) if @selected_class
      scope = scope.where(status: @status) if @status

      @requests = scope.limit(200)
      count_scope = @selected_class ? AttendanceRequest.where(school_class: @selected_class) : AttendanceRequest.all
      @request_counts = count_scope.group(:status).count
    else
      @classes = current_user.enrolled_classes.order(:name)
      @requests = current_user.attendance_requests.includes(:school_class, :class_session).order(submitted_at: :desc).limit(200)
      @request = AttendanceRequest.new
    end
  end

  def create
    require_role!("student")

    request_params = params.require(:attendance_request).permit(:school_class_id, :date, :request_type, :reason)
    school_class = current_user.enrolled_classes.find(request_params[:school_class_id])
    date = Date.parse(request_params[:date])

    if AttendanceRequest.where(user: current_user, school_class: school_class, date: date, status: "pending").exists?
      redirect_to attendance_requests_path, alert: "この日付の申請がすでに送信されています。" and return
    end

    window = school_class.schedule_window(date)
    class_session = window&.dig(:class_session)

    request = current_user.attendance_requests.new(
      school_class: school_class,
      class_session: class_session,
      date: date,
      request_type: request_params[:request_type],
      reason: request_params[:reason],
      submitted_at: Time.current
    )

    if request.save
      Notification.create!(
        user: school_class.teacher,
        kind: "info",
        title: "出席申請が届きました",
        body: "#{school_class.name} (#{date.strftime('%Y-%m-%d')}) の#{request.request_type}申請があります。",
        action_path: attendance_requests_path(class_id: school_class.id, status: "pending")
      )

      redirect_to attendance_requests_path, notice: "出席申請を送信しました。"
    else
      redirect_to attendance_requests_path, alert: request.errors.full_messages.join("、")
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to attendance_requests_path, alert: "クラスが見つかりません。"
  rescue ArgumentError
    redirect_to attendance_requests_path, alert: "日付の形式が正しくありません。"
  end

  def update
    require_role!(%w[teacher admin])

    unless current_user.manageable_classes.exists?(id: @request.school_class_id)
      redirect_to attendance_requests_path, alert: "権限がありません。" and return
    end

    update_params = params.require(:attendance_request).permit(:status, :decision_reason)
    status = update_params[:status].to_s

    unless %w[approved rejected].include?(status)
      redirect_to attendance_requests_path, alert: "ステータスが不正です。" and return
    end

    if @request.status != "pending"
      redirect_to attendance_requests_path, alert: "この申請は処理済みです。" and return
    end

    @request.update!(
      status: status,
      processed_by: current_user,
      processed_at: Time.current,
      decision_reason: update_params[:decision_reason]
    )

    if @request.status_approved?
      apply_request_to_attendance!(@request)
    end

    Notification.create!(
      user: @request.user,
      kind: @request.status_approved? ? "info" : "warning",
      title: "出席申請が#{@request.status_approved? ? "承認" : "却下"}されました",
      body: "#{@request.school_class.name} (#{@request.date.strftime('%Y-%m-%d')}) の申請結果をご確認ください。",
      action_path: attendance_requests_path
    )

    redirect_to attendance_requests_path, notice: "申請を更新しました。"
  end

  def bulk_update
    require_role!(%w[teacher admin])

    request_ids = Array(params[:request_ids]).map(&:to_i).uniq
    status = params[:status].to_s
    decision_reason = params[:decision_reason]

    if request_ids.empty?
      redirect_to attendance_requests_path, alert: "申請が選択されていません。" and return
    end

    unless %w[approved rejected].include?(status)
      redirect_to attendance_requests_path, alert: "ステータスが不正です。" and return
    end

    class_ids = current_user.manageable_classes.pluck(:id)
    requests = AttendanceRequest
               .includes(:user, :school_class, :class_session)
               .where(id: request_ids, status: "pending", school_class_id: class_ids)

    if requests.empty?
      redirect_to attendance_requests_path, alert: "対象の申請がありません。" and return
    end

    processed = 0
    AttendanceRequest.transaction do
      requests.each do |request|
        process_request!(request, status: status, decision_reason: decision_reason)
        processed += 1
      end
    end

    redirect_to attendance_requests_path(class_id: params[:class_id], status: params[:filter_status]),
                notice: "申請を一括更新しました。(#{processed}件)"
  end

  private

  def load_request
    @request = AttendanceRequest.find(params[:id])
  end

  def apply_request_to_attendance!(attendance_request)
    record = AttendanceRecord.find_or_initialize_by(
      user: attendance_request.user,
      school_class: attendance_request.school_class,
      date: attendance_request.date
    )
    previous_status = record.status

    record.status = attendance_request.request_type
    record.verification_method = "manual"
    record.timestamp ||= Time.current
    record.modified_by = current_user
    record.modified_at = Time.current
    record.class_session ||= attendance_request.class_session || ClassSessionResolver.new(
      school_class: attendance_request.school_class,
      date: attendance_request.date
    )&.resolve&.dig(:session)
    record.save!

    return if previous_status.nil? || previous_status == record.status

    AttendanceChange.create!(
      attendance_record: record,
      user: attendance_request.user,
      school_class: attendance_request.school_class,
      date: attendance_request.date,
      previous_status: previous_status,
      new_status: record.status,
      reason: attendance_request.reason.presence || "出席申請承認",
      modified_by: current_user,
      source: "manual",
      ip: request.remote_ip,
      user_agent: request.user_agent,
      changed_at: Time.current
    )
  end

  def process_request!(request, status:, decision_reason:)
    request.update!(
      status: status,
      processed_by: current_user,
      processed_at: Time.current,
      decision_reason: decision_reason
    )

    apply_request_to_attendance!(request) if request.status_approved?

    Notification.create!(
      user: request.user,
      kind: request.status_approved? ? "info" : "warning",
      title: "出席申請が#{request.status_approved? ? "承認" : "却下"}されました",
      body: "#{request.school_class.name} (#{request.date.strftime('%Y-%m-%d')}) の申請結果をご確認ください。",
      action_path: attendance_requests_path
    )
  end
end
