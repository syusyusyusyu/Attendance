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
      enable_push_preference
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

    disable_push_preference if current_user.push_subscriptions.none?

    render json: { ok: true }
  end

  def test
    if current_user.push_subscriptions.none?
      render json: { ok: false, error: "Push通知が有効化されていません。" }, status: :unprocessable_entity
      return
    end

    unless ENV["WEBPUSH_PUBLIC_KEY"].present? && ENV["WEBPUSH_PRIVATE_KEY"].present?
      render json: { ok: false, error: "WEBPUSH鍵が設定されていません。" }, status: :unprocessable_entity
      return
    end

    notification = current_user.notifications.create!(
      title: "テスト通知",
      body: "Push通知が正常に動作しています。",
      kind: "info",
      action_path: "/profile"
    )

    PushNotifier.new(notification, action_url: "/profile").deliver

    render json: { ok: true }
  rescue => e
    Rails.logger.error("テストPush通知の送信に失敗: #{e.class} #{e.message}")
    render json: { ok: false, error: "送信に失敗しました: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def subscription_params
    params.require(:subscription).permit(:endpoint, keys: [:p256dh, :auth])
  end

  def enable_push_preference
    settings = current_user.settings || {}
    notifications = settings["notifications"] || {}
    notifications["push"] = true
    settings["notifications"] = notifications
    current_user.update_columns(settings: settings)
  end

  def disable_push_preference
    settings = current_user.settings || {}
    notifications = settings["notifications"] || {}
    notifications["push"] = false
    settings["notifications"] = notifications
    current_user.update_columns(settings: settings)
  end
end
