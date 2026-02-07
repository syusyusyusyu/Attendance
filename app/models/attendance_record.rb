class AttendanceRecord < ApplicationRecord
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
    system: "system",
    roll_call: "roll_call"
  }, prefix: true

  validates :date, :status, :verification_method, presence: true
  validates :user_id, uniqueness: { scope: [:school_class_id, :date] }

  before_save :sync_duration_minutes
  after_commit :broadcast_attendance_update, on: [:create, :update]

  def self.normalize_status(value)
    AttendanceStatus.normalize(value)
  end

  def status_label
    AttendanceStatus.label(status)
  end

  def status_badge_class
    AttendanceStatus.badge_class(status)
  end

  private

  def sync_duration_minutes
    return if checked_in_at.blank? || checked_out_at.blank?

    self.duration_minutes = ((checked_out_at - checked_in_at) / 60).to_i
  end

  def broadcast_attendance_update
    return if Rails.env.test? || ENV["SEEDING"].present?
    return unless ActionCable.server.pubsub.respond_to?(:broadcast)

    pending_request = AttendanceRequest.find_by(
      school_class_id: school_class_id,
      user_id: user_id,
      date: date,
      status: "pending"
    )

    Turbo::StreamsChannel.broadcast_replace_to(
      "attendance_class_#{school_class_id}_#{date}",
      target: "attendance_row_#{user_id}",
      partial: "class_attendances/attendance_row",
      locals: {
        student: user,
        record: self,
        request: pending_request,
        class_session: class_session,
        policy: school_class&.attendance_policy
      }
    )
  rescue Gem::LoadError, Redis::CannotConnectError, SocketError => e
    Rails.logger.warn("Broadcast skipped: #{e.message}")
  end
end
