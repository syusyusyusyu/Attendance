class AddThresholdsToAttendancePolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :attendance_policies, :minimum_attendance_rate, :integer, null: false, default: 80
    add_column :attendance_policies, :warning_absent_count, :integer, null: false, default: 3
    add_column :attendance_policies, :warning_rate_percent, :integer, null: false, default: 70
  end
end
