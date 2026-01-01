class Admin::SsoProvidersController < Admin::BaseController
  before_action -> { require_permission!("admin.sso.manage") }
  before_action :load_provider, only: [:edit, :update]

  def index
    @providers = SsoProvider.order(:name)
    @provider = SsoProvider.new
  end

  def create
    @provider = SsoProvider.new(provider_params)
    if @provider.save
      redirect_to admin_sso_providers_path, notice: "SSO設定を追加しました。"
    else
      @providers = SsoProvider.order(:name)
      render :index, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @provider.update(provider_params)
      redirect_to admin_sso_providers_path, notice: "SSO設定を更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def load_provider
    @provider = SsoProvider.find(params[:id])
  end

  def provider_params
    params.require(:sso_provider).permit(
      :name,
      :strategy,
      :client_id,
      :client_secret,
      :authorize_url,
      :token_url,
      :issuer,
      :enabled
    )
  end
end
