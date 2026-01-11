class AdminDashboardController < ApplicationController
  before_action -> { require_role!("admin") }

  def index
    @users = User.order(:role, :name)
    @role_counts = User.group(:role).count
    @pending_requests = AttendanceRequest
                        .includes(:user, :school_class)
                        .where(status: "pending")
                        .order(submitted_at: :desc)
                        .limit(10)
    @pending_operations = OperationRequest
                          .includes(:user, :school_class)
                          .where(status: "pending")
                          .order(created_at: :desc)
                          .limit(10)
    @recent_changes = AttendanceChange
                      .includes(:user, :modified_by, :school_class)
                      .order(changed_at: :desc)
                      .limit(20)
    @recent_scans = QrScanEvent
                    .includes(:user, :school_class)
                    .order(scanned_at: :desc)
                    .limit(20)
    @scan_status_counts = QrScanEvent
                          .where(scanned_at: 7.days.ago..Time.current)
                          .group(:status)
                          .count
    @change_source_counts = AttendanceChange
                            .where(changed_at: 7.days.ago..Time.current)
                            .group(:source)
                            .count
  end
end
