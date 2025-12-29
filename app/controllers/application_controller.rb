class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login
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

  def require_role!(role)
    return if current_user&.role == role

    redirect_to root_path, alert: "アクセス権限がありません。"
  end
end
