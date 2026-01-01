class AttendanceRecord < ApplicationRecord
  STATUS_LABELS = {
    "present" => "出席",
    "late" => "遅刻",
    "absent" => "欠席",
    "excused" => "公欠",
    "early_leave" => "早退"
  }.freeze

  STATUS_BADGE_CLASSES = {
    "present" => "badge badge-success",
    "late" => "badge badge-warning",
    "absent" => "badge badge-error",
    "excused" => "badge badge-info",
    "early_leave" => "badge badge-warning"
  }.freeze

  CSV_STATUS_MAP = {
    "出席" => "present",
    "遅刻" => "late",
    "欠席" => "absent",
    "公欠" => "excused",
    "早退" => "early_leave",
    "未入力" => :skip,
    "present" => "present",
    "late" => "late",
    "absent" => "absent",
    "excused" => "excused",
    "early_leave" => "early_leave"
  }.freeze

  belongs_to :user
  belongs_to :school_class
  belongs_to :class_session, optional: true
  belongs_to :modified_by, class_name: "User", optional: true
  has_many :attendance_changes, dependent: :nullify

  enum :status, {
    present: "present",
    absent: "absent",
    late: "late",
    excused: "excused",
    early_leave: "early_leave"
  }, prefix: true

  enum :verification_method, {
    qrcode: "qrcode",
    manual: "manual",
    gps: "gps",
    beacon: "beacon",
    system: "system"
  }, prefix: true

  validates :date, :status, :verification_method, presence: true
  validates :user_id, uniqueness: { scope: [:school_class_id, :date] }

  before_save :sync_duration_minutes
  after_commit :broadcast_attendance_update, on: [:create, :update]

  def self.normalize_status(value)
    text = value.to_s.strip
    return nil if text.blank?

    CSV_STATUS_MAP[text]
  end

  def status_label
    STATUS_LABELS[status]
  end

  def status_badge_class
    STATUS_BADGE_CLASSES[status] || "badge"
  end

  private

  def sync_duration_minutes
    return if checked_in_at.blank? || checked_out_at.blank?

    self.duration_minutes = ((checked_out_at - checked_in_at) / 60).to_i
  end

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
