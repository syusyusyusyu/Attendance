class RollCallsController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("attendance.manage") }

  def show
    @classes = current_user.manageable_classes.order(:name)
    selected_class_id = params[:class_id].presence || session[:roll_call_class_id]
    selected_class_id = @classes.first.id if selected_class_id.blank? && @classes.one?
    @selected_class = @classes.find_by(id: selected_class_id)

    if @selected_class
      session[:roll_call_class_id] = @selected_class.id
    else
      session.delete(:roll_call_class_id)
    end

    @date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    return unless @selected_class

    @students = @selected_class.students.order(:name)
    @records = AttendanceRecord
               .where(school_class: @selected_class, date: @date)
               .index_by(&:user_id)

    @total = @students.size
    @confirmed = @records.count { |_, r| r.status_present? || r.status_late? }
  rescue ArgumentError
    redirect_to roll_call_path, alert: "日付の形式が正しくありません。"
  end

  VALID_STATUSES = %w[present absent late excused early_leave].freeze

  def update
    selected_class = current_user.manageable_classes.find(params[:class_id])
    date = params[:date].present? ? Date.parse(params[:date]) : Date.current

    window = selected_class.schedule_window(date)
    class_session = window&.dig(:class_session)

    if class_session&.locked? && !current_user.admin?
      redirect_to roll_call_path(class_id: selected_class.id, date: date),
                  alert: "出席が確定済みのため修正できません。" and return
    end

    attendance = params[:attendance] || {}
    registered = 0

    attendance.each do |student_id, status|
      next unless VALID_STATUSES.include?(status)

      record = AttendanceRecord.find_or_initialize_by(
        user_id: student_id.to_i,
        school_class: selected_class,
        date: date
      )

      next if record.persisted? && record.verification_method_qrcode?

      previous_status = record.status
      record.status = status
      record.verification_method = "roll_call"
      record.timestamp ||= Time.current
      record.modified_by = current_user
      record.modified_at = Time.current
      record.class_session ||= class_session if class_session
      record.save!
      registered += 1

      next if previous_status.nil? || previous_status == record.status

      AttendanceChange.create!(
        attendance_record: record,
        user: record.user,
        school_class: selected_class,
        date: date,
        previous_status: previous_status,
        new_status: record.status,
        reason: "点呼",
        modified_by: current_user,
        source: "manual",
        ip: request.remote_ip,
        user_agent: request.user_agent,
        changed_at: Time.current
      )
    end

    redirect_to roll_call_path(class_id: selected_class.id, date: date),
                notice: "点呼を完了しました。#{registered}名の出席を登録しました。"
  rescue ArgumentError
    redirect_to roll_call_path, alert: "日付の形式が正しくありません。"
  end
end
