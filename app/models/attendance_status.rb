class AttendanceStatus
  LABELS = {
    "present" => "出席",
    "late" => "遅刻",
    "absent" => "欠席",
    "excused" => "公欠",
    "early_leave" => "早退"
  }.freeze

  BADGE_CLASSES = {
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

  def self.normalize(value)
    text = value.to_s.strip
    return nil if text.blank?

    CSV_STATUS_MAP[text]
  end

  def self.label(status)
    LABELS[status.to_s]
  end

  def self.badge_class(status)
    BADGE_CLASSES[status.to_s] || "badge"
  end
end
