class AttendanceChange < ApplicationRecord
  belongs_to :attendance_record, optional: true
  belongs_to :user, optional: true
  belongs_to :school_class, optional: true
  belongs_to :modified_by, class_name: "User", optional: true

  enum :source, {
    manual: "manual",
    csv: "csv",
    system: "system"
  }, prefix: true

  validates :date, :new_status, :changed_at, :reason, presence: true
end
