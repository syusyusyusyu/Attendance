class OperationRequest < ApplicationRecord
  belongs_to :user
  belongs_to :school_class, optional: true
  belongs_to :processed_by, class_name: "User", optional: true

  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected"
  }, prefix: true

  enum :kind, {
    attendance_correction: "attendance_correction",
    attendance_finalize: "attendance_finalize",
    attendance_unlock: "attendance_unlock",
    attendance_csv_import: "attendance_csv_import"
  }, prefix: true

  validates :kind, :status, presence: true
end
