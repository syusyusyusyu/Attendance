class PushSubscriptionsController < ApplicationController
  before_action -> { require_permission!("profile.manage") }

  def create
    subscription = subscription_params.to_h
    endpoint = subscription["endpoint"].to_s.strip
    keys = subscription["keys"] || {}
    p256dh = keys["p256dh"] || keys[:p256dh]
    auth = keys["auth"] || keys[:auth]

    if endpoint.blank? || p256dh.blank? || auth.blank?
      render json: { ok: false, error: "subscription_invalid" }, status: :unprocessable_entity and return
    end

    record = current_user.push_subscriptions.find_or_initialize_by(endpoint: endpoint)
    record.assign_attributes(
      p256dh: p256dh,
      auth: auth,
      user_agent: request.user_agent
    )

    if record.save
      render json: { ok: true }
    else
      render json: { ok: false, error: record.errors.full_messages.join("、") }, status: :unprocessable_entity
    end
  end

  def destroy
    endpoint = params[:endpoint].to_s.strip
    if endpoint.present?
      current_user.push_subscriptions.where(endpoint: endpoint).delete_all
    end

    render json: { ok: true }
  end

  def test
    if current_user.push_subscriptions.none?
      render json: { ok: false, error: "Push通知が有効化されていません。" }, status: :unprocessable_entity
      return
    end

    notification = current_user.notifications.create!(
      title: "テスト通知",
      body: "Push通知が正常に動作しています。",
      kind: "info",
      action_path: "/profile"
    )

    render json: { ok: true }
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
  end
end
