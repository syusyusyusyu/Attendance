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

    payload = {
      title: "テスト通知",
      options: {
        body: "Push通知が正常に動作しています。",
        data: { path: "/profile" }
      }
    }

    vapid = {
      subject: ENV.fetch("WEBPUSH_SUBJECT", "mailto:admin@example.com"),
      public_key: ENV.fetch("WEBPUSH_PUBLIC_KEY"),
      private_key: ENV.fetch("WEBPUSH_PRIVATE_KEY")
    }

    errors = []
    current_user.push_subscriptions.find_each do |sub|
      Webpush.payload_send(
        message: JSON.generate(payload),
        endpoint: sub.endpoint,
        p256dh: sub.p256dh,
        auth: sub.auth,
        vapid: vapid
      )
    rescue Webpush::InvalidSubscription, Webpush::ExpiredSubscription
      sub.destroy
      errors << "無効なsubscription（削除済み）"
    rescue => e
      errors << e.message
    end

    if errors.any?
      render json: { ok: false, error: errors.join(", ") }, status: :unprocessable_entity
    else
      render json: { ok: true }
    end
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
