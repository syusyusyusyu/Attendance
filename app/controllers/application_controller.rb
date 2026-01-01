class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login
  before_action :set_unread_notifications_count
  before_action :set_pending_requests_count
  before_action :ensure_device_id
  helper_method :current_user, :current_device

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  def current_device
    return nil unless current_user

    device_id = cookies.signed[:device_id]
    return nil if device_id.blank?

    @current_device ||= current_user.devices.find_or_create_by!(device_id: device_id) do |device|
      device.name = "未登録端末"
      device.user_agent = request.user_agent
      device.ip = request.remote_ip
      device.last_seen_at = Time.current
      device.approved = false
    end
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

  def require_permission!(permission_key)
    return if current_user&.has_permission?(permission_key)

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

  def ensure_device_id
    return unless current_user

    return if cookies.signed[:device_id].present?

    cookies.signed[:device_id] = {
      value: SecureRandom.uuid,
      expires: 1.year.from_now,
      httponly: true,
      same_site: :lax
    }
  end
end
