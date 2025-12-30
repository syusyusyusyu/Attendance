class AttendanceRequest < ApplicationRecord
  belongs_to :user
  belongs_to :school_class
  belongs_to :class_session, optional: true
  belongs_to :processed_by, class_name: "User", optional: true

  enum :request_type, {
    absent: "absent",
    late: "late",
    excused: "excused"
  }, prefix: true

  enum :status, {
    pending: "pending",
    approved: "approved",
    rejected: "rejected"
  }, prefix: true

  validates :date, :request_type, :status, :submitted_at, presence: true
  validates :reason, presence: true, length: { maximum: 1000 }
end
