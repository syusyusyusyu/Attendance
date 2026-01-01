class Notification < ApplicationRecord
  belongs_to :user

  enum :kind, {
    info: "info",
    warning: "warning",
    success: "success"
  }, prefix: true

  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }

  after_create_commit :enqueue_delivery

  def mark_read!
    update!(read_at: Time.current)
  end

  private

  def enqueue_delivery
    NotificationDeliveryJob.perform_later(id)
  end
end
