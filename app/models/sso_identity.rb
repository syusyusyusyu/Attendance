class SsoIdentity < ApplicationRecord
  belongs_to :user
  belongs_to :sso_provider

  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :sso_provider_id }
end
