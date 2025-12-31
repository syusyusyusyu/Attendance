class SessionsController < ApplicationController
  skip_before_action :require_login, only: [:new, :create]

  def new
    redirect_to root_path if current_user
  end

  def create
    user = User.find_by(email: params[:email].to_s.downcase)

    if user&.authenticate(params[:password])
      first_login = user.last_login.blank?
      session[:user_id] = user.id
      user.update!(last_login: Time.current)
      session[:show_onboarding] = true if first_login
      redirect_to root_path, notice: "ログインしました。"
    else
      flash.now[:alert] = "メールアドレスまたはパスワードが間違っています。"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "ログアウトしました。"
  end
end
