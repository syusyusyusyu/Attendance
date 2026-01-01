class QrSession < ApplicationRecord
  belongs_to :school_class
  belongs_to :teacher, class_name: "User"

  validates :attendance_date, :issued_at, :expires_at, presence: true
  validate :expires_after_issued

  def revoked?
    revoked_at.present?
  end

  def active?(reference_time = Time.current)
    !revoked? && expires_at > reference_time
  end

  private

  def expires_after_issued
    return if expires_at.blank? || issued_at.blank?

    if expires_at <= issued_at
      errors.add(:expires_at, "は発行時刻より後に設定してください")
    end
  end
end
