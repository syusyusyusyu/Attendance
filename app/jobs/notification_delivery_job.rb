class NotificationDeliveryJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET,
           wait: :polynomially_longer, attempts: 5

  discard_on ActiveRecord::RecordNotFound

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return unless notification

    NotificationDispatcher.new(notification).deliver
  end
end
