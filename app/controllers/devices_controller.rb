class DevicesController < ApplicationController
  def update
    device = current_user.devices.find(params[:id])

    if device.update(device_params)
      redirect_to profile_path, notice: "端末名を更新しました。"
    else
      redirect_to profile_path, alert: "端末名の更新に失敗しました。"
    end
  end

  def request_approval
    device = current_user.devices.find(params[:id])

    User.where(role: "admin").find_each do |admin|
      Notification.create!(
        user: admin,
        kind: "warning",
        title: "端末承認の申請が届きました",
        body: "#{current_user.name} の端末(#{device.name.presence || "未登録端末"})が承認申請されました。",
        action_path: admin_devices_path(status: "pending")
      )
    end

    redirect_to profile_path, notice: "端末承認を申請しました。"
  end

  private

  def device_params
    params.require(:device).permit(:name)
  end
end
