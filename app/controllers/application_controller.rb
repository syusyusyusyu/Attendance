class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login
  before_action :set_unread_notifications_count
  before_action :set_pending_requests_count
  helper_method :current_user

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  def require_login
    return if current_user

    redirect_to login_path, alert: "ログインが必要です。"
  end

  def require_role!(*roles)
    allowed_roles = roles.flatten.map(&:to_s)
    return if current_user && allowed_roles.include?(current_user.role)

    redirect_to root_path, alert: "アクセス権限がありません。"
  end

  def set_unread_notifications_count
    return unless current_user

    @unread_notifications_count = current_user.notifications.unread.count
  end

  def set_pending_requests_count
    return unless current_user

    if current_user.staff?
      class_ids = current_user.manageable_classes.select(:id)
      @pending_requests_count = AttendanceRequest.where(school_class_id: class_ids, status: "pending").count
    else
      @pending_requests_count = current_user.attendance_requests.where(status: "pending").count
    end
  end
end
