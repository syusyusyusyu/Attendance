class ClassSessionOverridesController < ApplicationController
  before_action -> { require_role!(%w[teacher admin]) }
  before_action -> { require_permission!("session.override.manage") }

  def create
    school_class = current_user.manageable_classes.find(params[:school_class_id])
    override = school_class.class_session_overrides.new(override_params)

    if override.save
      ClassSessionResolver.new(school_class: school_class, date: override.date).resolve
      notify_students(school_class, override)
      redirect_to school_class_path(school_class), notice: "特別日程を追加しました。"
    else
      redirect_to school_class_path(school_class), alert: override.errors.full_messages.join("、")
    end
  end

  def destroy
    school_class = current_user.manageable_classes.find(params[:school_class_id])
    override = school_class.class_session_overrides.find(params[:id])
    override.destroy
    unless ClassSessionResolver.new(school_class: school_class, date: override.date).resolve
      school_class.class_sessions.where(date: override.date).delete_all
    end
    redirect_to school_class_path(school_class), notice: "特別日程を削除しました。"
  end

  private

  def override_params
    params.require(:class_session_override).permit(:date, :start_time, :end_time, :status, :note)
  end

  def notify_students(school_class, override)
    return unless override.status_canceled? || override.status_makeup?

    title = override.status_canceled? ? "休講のお知らせ" : "補講のお知らせ"
    body = "#{school_class.name} (#{override.date.strftime('%Y-%m-%d')}) の予定が更新されました。"

    notifications = school_class.students.map do |student|
      {
        user_id: student.id,
        kind: "info",
        title: title,
        body: body,
        action_path: history_path(date: override.date),
        created_at: Time.current,
        updated_at: Time.current
      }
    end

    notifications.each { |attrs| Notification.create!(attrs) }
  end
end
