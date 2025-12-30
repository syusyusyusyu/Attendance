class AttendanceRecord < ApplicationRecord
  belongs_to :user
  belongs_to :school_class
  belongs_to :modified_by, class_name: "User", optional: true
  has_many :attendance_changes, dependent: :nullify

  enum :status, {
    present: "present",
    absent: "absent",
    late: "late",
    excused: "excused"
  }, prefix: true

  enum :verification_method, {
    qrcode: "qrcode",
    manual: "manual",
    gps: "gps",
    beacon: "beacon"
  }, prefix: true

  validates :date, :status, :verification_method, presence: true
  validates :user_id, uniqueness: { scope: [:school_class_id, :date] }

  after_commit :broadcast_attendance_update, on: [:create, :update]

  def status_label
    {
      "present" => "出席",
      "late" => "遅刻",
      "absent" => "欠席",
      "excused" => "公欠"
    }[status]
  end

  def status_badge_class
    {
      "present" => "badge badge-success",
      "late" => "badge badge-warning",
      "absent" => "badge badge-error",
      "excused" => "badge badge-info"
    }[status] || "badge"
  end

  private

  def broadcast_attendance_update
    return unless verification_method_qrcode?

    Turbo::StreamsChannel.broadcast_replace_to(
      "attendance_class_#{school_class_id}_#{date}",
      target: "attendance_row_#{user_id}",
      partial: "class_attendances/attendance_row",
      locals: { student: user, record: self }
    )
  end
end
