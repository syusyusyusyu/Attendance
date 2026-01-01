class Admin::UsersController < Admin::BaseController
  before_action -> { require_permission!("admin.users.manage") }
  before_action :load_user, only: [:edit, :update]

  def index
    @query = params[:q].to_s.strip
    @role = params[:role].presence

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
      redirect_to admin_users_path, notice: "ユーザーを作成しました。"
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
      redirect_to admin_users_path, notice: "ユーザーを更新しました。"
    else
      render :edit, status: :unprocessable_entity
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
