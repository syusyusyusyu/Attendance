class Notification < ApplicationRecord
  belongs_to :user

  enum :kind, {
    info: "info",
    warning: "warning",
    success: "success"
  }, prefix: true

  validates :title, presence: true

  scope :unread, -> { where(read_at: nil) }

  def mark_read!
    update!(read_at: Time.current)
  end
end
