class Admin::DevicesController < Admin::BaseController
  before_action -> { require_permission!("admin.devices.approve") }

  def index
    @status = params[:status].presence

    scope = Device.includes(:user).order(last_seen_at: :desc)
    if @status == "approved"
      scope = scope.where(approved: true)
    elsif @status == "pending"
      scope = scope.where(approved: false)
    end

    @devices = scope.limit(200)
  end

  def update
    device = Device.find(params[:id])
    approved = params[:approved].to_s == "1"

    device.update!(approved: approved)

    if approved
      Notification.create!(
        user: device.user,
        kind: "info",
        title: "端末が承認されました",
        body: "登録済み端末が承認されました。QRスキャンが利用できます。",
        action_path: profile_path
      )
    end

    redirect_to admin_devices_path, notice: "端末情報を更新しました。"
  end
end
