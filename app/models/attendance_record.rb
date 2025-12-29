class AttendanceRecord < ApplicationRecord
  belongs_to :user
  belongs_to :school_class
  belongs_to :modified_by, class_name: "User", optional: true

  enum :status, {
    present: "present",
    absent: "absent",
    late: "late",
    excused: "excused"
  }, _prefix: true

  enum :verification_method, {
    qrcode: "qrcode",
    manual: "manual",
    gps: "gps",
    beacon: "beacon"
  }, _prefix: true

  validates :date, :status, :verification_method, presence: true
  validates :user_id, uniqueness: { scope: [:school_class_id, :date] }

  def status_label
    {
      "present" => "出席",
      "late" => "遅刻",
      "absent" => "欠席",
      "excused" => "公欠"
    }[status]
  end
end
