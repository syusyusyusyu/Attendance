class AddSecurityControlsToAttendancePolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :attendance_policies, :student_max_scans_per_minute, :integer, null: false, default: 6
    add_column :attendance_policies, :require_registered_device, :boolean, null: false, default: false
    add_column :attendance_policies, :fraud_failure_threshold, :integer, null: false, default: 4
    add_column :attendance_policies, :fraud_ip_burst_threshold, :integer, null: false, default: 8
    add_column :attendance_policies, :fraud_token_share_threshold, :integer, null: false, default: 2
  end
end
