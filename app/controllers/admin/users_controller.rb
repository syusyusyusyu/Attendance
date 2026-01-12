class Admin::UsersController < Admin::BaseController
  before_action -> { require_permission!("admin.users.manage") }
  before_action :load_user, only: [:edit, :update, :destroy]

  def index
    stored = session[:admin_users_last_filter].is_a?(Hash) ? session[:admin_users_last_filter] : {}

    @query =
      if params.key?(:q)
        params[:q].to_s.strip
      else
        stored["q"].to_s.strip
      end
    @role =
      if params.key?(:role)
        params[:role].presence
      else
        stored["role"].presence
      end
    session[:admin_users_last_filter] = { "q" => @query, "role" => @role }.compact_blank

    scope = User.order(:role, :name)
    scope = scope.where(role: @role) if @role
    if @query.present?
      scope = scope.where("name ILIKE :q OR email ILIKE :q OR student_id ILIKE :q", q: "%#{@query}%")
    end

    @users = scope.limit(200)
  end

  def new
    @user = User.new
  end

  def create
    attrs = user_params
    if attrs[:role].to_s == "student" && attrs[:password].blank?
      default_password = attrs[:student_id].to_s.strip
      if default_password.present?
        attrs[:password] = default_password
        attrs[:password_confirmation] = default_password
      end
    end

    @user = User.new(attrs)
    if @user.save
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "ユーザーを作成しました。" }
        format.html { redirect_to admin_users_path, notice: "ユーザーを作成しました。" }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    attrs = user_update_params
    if attrs[:password].blank?
      attrs.delete(:password)
      attrs.delete(:password_confirmation)
    end

    if @user.update(attrs)
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "ユーザーを更新しました。" }
        format.html { redirect_to admin_users_path, notice: "ユーザーを更新しました。" }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @user == current_user
      redirect_to admin_users_path, alert: "自分のアカウントは削除できません。"
      return
    end

    if @user.admin? && User.admin.count <= 1
      redirect_to admin_users_path, alert: "最後の管理者は削除できません。"
      return
    end

    @user.destroy!
    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "ユーザーを削除しました。" }
      format.html { redirect_to admin_users_path, notice: "ユーザーを削除しました。" }
    end
  end

  private

  def load_user
    @user = User.find(params[:id])
  end

  def user_params
    params.require(:user).permit(:name, :email, :student_id, :role, :password, :password_confirmation)
  end

  def user_update_params
    params.require(:user).permit(:name, :email, :student_id, :role, :password, :password_confirmation)
  end
end
