require "digest"

class Api::BaseController < ActionController::API
  before_action :authenticate_api_key!

  attr_reader :current_api_key, :current_api_user

  private

  def authenticate_api_key!
    token = request.headers["Authorization"].to_s.sub(/^Bearer /, "")
    token = request.headers["X-API-KEY"].to_s if token.blank?

    if token.blank?
      render json: { error: "APIキーが必要です。" }, status: :unauthorized and return
    end

    digest = Digest::SHA256.hexdigest(token)
    key = ApiKey.active.find_by(token_digest: digest)

    unless key
      render json: { error: "APIキーが無効です。" }, status: :unauthorized and return
    end

    key.update(last_used_at: Time.current)
    @current_api_key = key
    @current_api_user = key.user
  end

  def require_scope!(scope)
    return true if current_api_key&.scopes&.include?(scope)

    render json: { error: "権限がありません。" }, status: :forbidden
    false
  end
end
