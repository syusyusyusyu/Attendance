class AddSecurityFieldsToAttendancePolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :attendance_policies, :allowed_ip_ranges, :text
    add_column :attendance_policies, :allowed_user_agent_keywords, :text
    add_column :attendance_policies, :max_scans_per_minute, :integer, null: false, default: 10
  end
end
