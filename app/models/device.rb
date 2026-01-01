class Device < ApplicationRecord
  belongs_to :user

  validates :device_id, presence: true
  validates :device_id, uniqueness: { scope: :user_id }

  scope :approved, -> { where(approved: true) }
end
