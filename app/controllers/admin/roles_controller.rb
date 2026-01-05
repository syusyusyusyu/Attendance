class Admin::RolesController < Admin::BaseController
  before_action -> { require_permission!("admin.roles.manage") }

  def index
    @roles = Role.includes(:permissions).order(:name)
    @permissions = Permission.where.not(key: "admin.sso.manage").order(:key)
  end

  def update
    role = Role.find(params[:id])
    attrs = params.require(:role).permit(:label, :description)
    permission_ids = Array(params[:permission_ids]).map(&:to_i)

    role.update(attrs)
    role.permission_ids = permission_ids

    redirect_to admin_roles_path, notice: "権限を更新しました。"
  end
end
