class Admin::RolesController < Admin::BaseController
  before_action -> { require_permission!("admin.roles.manage") }

  def index
    @roles = Role.includes(:permissions).order(:name)
    @permissions = Permission.order(:key)
  end

  def update
    @roles = Role.includes(:permissions).order(:name)
    @permissions = Permission.order(:key)
    @role = Role.find(params[:id])
    attrs = params.require(:role).permit(:label, :description)
    permission_ids = Array(params[:permission_ids]).map(&:to_i)

    ActiveRecord::Base.transaction do
      @role.update!(attrs)
      @role.permission_ids = permission_ids
    end

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "権限を更新しました。" }
      format.html { redirect_to admin_roles_path, notice: "権限を更新しました。" }
    end
  rescue StandardError => e
    respond_to do |format|
      format.turbo_stream do
        flash.now[:alert] = "権限の更新に失敗しました。"
        render turbo_stream: [
          turbo_stream.replace(
            dom_id(@role),
            partial: "admin/roles/card",
            locals: { role: @role, permissions: @permissions, error_message: e.message }
          ),
          turbo_stream.update("flash", partial: "shared/flash")
        ], status: :unprocessable_entity
      end
      format.html { redirect_to admin_roles_path, alert: "権限の更新に失敗しました: #{e.message}" }
    end
  end
end
