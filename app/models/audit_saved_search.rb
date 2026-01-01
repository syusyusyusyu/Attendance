class AuditSavedSearch < ApplicationRecord
  belongs_to :user

  validates :name, presence: true
  validates :scope, presence: true
  validates :name, uniqueness: { scope: [:user_id, :scope] }
end
