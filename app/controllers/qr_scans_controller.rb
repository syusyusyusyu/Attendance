class QrScansController < ApplicationController
  before_action -> { require_role!("student") }
  before_action -> { require_permission!("qr.scan") }

  def new
  end

  def create
    result = QrScanProcessor.new(
      user: current_user,
      token: params[:token],
      ip: request.remote_ip,
      user_agent: request.user_agent,
      device: current_device
    ).call

    redirect_to scan_path, result.flash => result.message
  end
end
