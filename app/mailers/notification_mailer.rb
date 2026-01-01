class NotificationMailer < ApplicationMailer
  def alert(notification, action_url: nil)
    @notification = notification
    @user = notification.user
    @action_url = action_url

    mail(to: @user.email, subject: @notification.title)
  end
end
