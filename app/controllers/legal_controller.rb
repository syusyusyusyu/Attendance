class LegalController < ApplicationController
  skip_before_action :require_login

  def terms
  end

  def privacy
  end

  def data_policy
  end
end
