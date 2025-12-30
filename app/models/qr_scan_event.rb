class QrScanEvent < ApplicationRecord
  belongs_to :qr_session, optional: true
  belongs_to :user, optional: true
  belongs_to :school_class, optional: true

  enum :status, {
    success: "success",
    invalid: "invalid",
    expired: "expired",
    revoked: "revoked",
    not_enrolled: "not_enrolled",
    duplicate: "duplicate",
    session_missing: "session_missing",
    wrong_date: "wrong_date",
    error: "error",
    early: "early",
    outside_window: "outside_window",
    rate_limited: "rate_limited",
    manual_override: "manual_override"
  }, prefix: true

  validates :status, :token_digest, :scanned_at, presence: true
end
