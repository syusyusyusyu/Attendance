class DashboardController < ApplicationController
  def show
    @user = current_user
    @classes =
      if @user.teacher?
        @user.taught_classes.order(:name)
      else
        @user.enrolled_classes.order(:name)
      end
  end
end
