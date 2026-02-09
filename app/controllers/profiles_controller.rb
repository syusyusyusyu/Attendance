class ProfilesController < ApplicationController
  before_action -> { require_permission!("profile.manage") }
  before_action :check_demo_account, only: [:update]

  def show
    @user = current_user
    @notification_preferences = current_user.notification_preferences
    @push_subscriptions = current_user.push_subscriptions
  end

  def update
    @user = current_user
    apply_notification_preferences
    apply_password_params

    attributes = params[:user].present? ? profile_params : {}
    if @user.update(attributes)
      redirect_to profile_path, notice: "プロフィールを更新しました。"
    else
      flash.now[:alert] = "プロフィールの更新に失敗しました。"
      render :show, status: :unprocessable_entity
    end
  end

  def update_theme
    theme = params[:theme].to_s
    unless %w[light dark].include?(theme)
      return head :unprocessable_entity
    end

    current_user.settings["theme"] = theme
    current_user.save!
    head :ok
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email, :student_id, :profile_image, :password, :password_confirmation)
  end

  def apply_notification_preferences
    return unless params[:notifications]

    prefs = params.require(:notifications).permit(:email, :line, :push, :line_user_id)
    settings = @user.settings || {}
    settings["notifications"] = {
      "email" => prefs[:email].to_s == "1",
      "line" => prefs[:line].to_s == "1",
      "push" => prefs[:push].to_s == "1"
    }
    settings["line_user_id"] = prefs[:line_user_id].to_s.strip if prefs.key?(:line_user_id)
    @user.settings = settings
  end

  def apply_password_params
    return unless params[:user]

    if params[:user][:password].blank?
      params[:user].delete(:password)
      params[:user].delete(:password_confirmation)
    end
  end

  def check_demo_account
    if current_user.demo_account? && params[:user].present?
      redirect_to profile_path, alert: "デモアカウントのプロフィールは変更できません。"
    end
  end
end
