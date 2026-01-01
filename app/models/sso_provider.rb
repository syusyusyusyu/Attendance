class SsoProvider < ApplicationRecord
  has_many :sso_identities, dependent: :destroy

  validates :name, :strategy, presence: true
  validates :name, uniqueness: true

  scope :enabled, -> { where(enabled: true) }
end
