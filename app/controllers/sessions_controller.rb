class SessionsController < ApplicationController
  MAX_LOGIN_ATTEMPTS = 5
  ATTEMPT_WINDOW = 10.minutes
  LOCKOUT_TIME = 15.minutes

  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to root_path if current_user
  end

  def create
    email = params[:email].to_s.downcase.strip
    ip = request.remote_ip

    if login_locked?(ip, email)
      flash.now[:alert] = "ログイン試行が多すぎます。しばらく待ってから再試行してください。"
      render :new, status: :too_many_requests
      return
    end

    user = User.find_by(email: email)

    if user&.authenticate(params[:password])
      clear_login_attempts(ip, email)
      first_login = user.last_login.blank?
      session[:user_id] = user.id
      user.update!(last_login: Time.current)
      session[:show_onboarding] = true if first_login
      redirect_path = session.delete(:return_to).presence || root_path
      redirect_to redirect_path, notice: "ログインしました。"
    else
      register_failed_login(ip, email)
      flash.now[:alert] = "メールアドレスまたはパスワードが間違っています。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "ログアウトしました。"
  end

  private

  def login_locked?(ip, email)
    Rails.cache.read(lock_key(ip, email)).present?
  end

  def register_failed_login(ip, email)
    count = Rails.cache.increment(attempt_key(ip, email), 1, expires_in: ATTEMPT_WINDOW)
    if count.nil?
      Rails.cache.write(attempt_key(ip, email), 1, expires_in: ATTEMPT_WINDOW)
      count = 1
    end

    return if count < MAX_LOGIN_ATTEMPTS

    Rails.cache.write(lock_key(ip, email), true, expires_in: LOCKOUT_TIME)
    Rails.cache.delete(attempt_key(ip, email))
  end

  def clear_login_attempts(ip, email)
    Rails.cache.delete(attempt_key(ip, email))
    Rails.cache.delete(lock_key(ip, email))
  end

  def attempt_key(ip, email)
    "login:attempts:#{ip}:#{email}"
  end

  def lock_key(ip, email)
    "login:lock:#{ip}:#{email}"
  end
end
