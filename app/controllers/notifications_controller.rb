class NotificationsController < ApplicationController
  before_action -> { require_permission!("notifications.view") }

  def index
    @notifications = current_user.notifications.order(created_at: :desc).limit(50)
  end

  def mark_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_read! if @notification.read_at.nil?
    @notifications = current_user.notifications.order(created_at: :desc)
    @unread_notifications_count = current_user.notifications.unread.count

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "通知を既読にしました。"
      end
      format.html do
        redirect_to notifications_path, notice: "通知を既読にしました。"
      end
    end
  end

  def mark_all
    current_user.notifications.unread.update_all(read_at: Time.current)
    @notifications = current_user.notifications.order(created_at: :desc)
    @unread_notifications_count = 0

    respond_to do |format|
      format.turbo_stream do
        flash.now[:notice] = "通知を既読にしました。"
      end
      format.html do
        redirect_to notifications_path, notice: "通知を既読にしました。"
      end
    end
  end
end
