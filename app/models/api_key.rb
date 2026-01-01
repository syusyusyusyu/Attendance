class ApiKey < ApplicationRecord
  belongs_to :user

  validates :name, :token_digest, presence: true
  validates :token_digest, uniqueness: true

  scope :active, -> { where(revoked_at: nil) }

  def self.generate!(user:, name:, scopes:)
    token = SecureRandom.hex(24)
    digest = Digest::SHA256.hexdigest(token)
    key = create!(user: user, name: name, token_digest: digest, scopes: Array(scopes))
    [key, token]
  end

  def active?
    revoked_at.nil?
  end

  def revoke!(timestamp = Time.current)
    update!(revoked_at: timestamp)
  end
end
