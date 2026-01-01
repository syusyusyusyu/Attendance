class NotificationsController < ApplicationController
  before_action -> { require_permission!("notifications.view") }

  def index
    @notifications = current_user.notifications.order(created_at: :desc)
  end

  def mark_all
    current_user.notifications.unread.update_all(read_at: Time.current)
    redirect_to notifications_path, notice: "通知を既読にしました。"
  end
end
