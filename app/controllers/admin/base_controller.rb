class Admin::BaseController < ApplicationController
  before_action :require_admin!

  private

  def require_admin!
    require_role!("admin")
  end
end
