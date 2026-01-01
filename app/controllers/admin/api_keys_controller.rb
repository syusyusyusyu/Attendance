class Admin::ApiKeysController < Admin::BaseController
  before_action -> { require_permission!("admin.api.manage") }

  SCOPES = %w[classes:read attendance:read students:read].freeze

  def index
    @api_keys = ApiKey.includes(:user).order(created_at: :desc)
    @scope_options = SCOPES
    @users = User.order(:name)
    @generated_token = flash[:api_token]
  end

  def create
    user = User.find(params[:user_id])
    scopes = Array(params[:scopes]).select { |scope| SCOPES.include?(scope) }

    key, token = ApiKey.generate!(user: user, name: params[:name], scopes: scopes)
    flash[:api_token] = token

    redirect_to admin_api_keys_path, notice: "APIキーを作成しました。"
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_api_keys_path, alert: "ユーザーが見つかりません。"
  end

  def update
    key = ApiKey.find(params[:id])

    if params[:revoke].to_s == "1"
      key.revoke!
      redirect_to admin_api_keys_path, notice: "APIキーを無効化しました。"
    else
      scopes = Array(params[:scopes]).select { |scope| SCOPES.include?(scope) }
      if key.update(name: params[:name], scopes: scopes)
        redirect_to admin_api_keys_path, notice: "APIキーを更新しました。"
      else
        redirect_to admin_api_keys_path, alert: key.errors.full_messages.join("、")
      end
    end
  end
end
