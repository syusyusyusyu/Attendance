class UpdateAttendancePolicyDefaults < ActiveRecord::Migration[8.0]
  def up
    change_column_default :attendance_policies, :late_after_minutes, from: 10, to: 5
    change_column_default :attendance_policies, :close_after_minutes, from: 90, to: 20

    execute <<~SQL.squish
      UPDATE attendance_policies
      SET late_after_minutes = 5,
          close_after_minutes = 20
    SQL
  end

  def down
    change_column_default :attendance_policies, :late_after_minutes, from: 5, to: 10
    change_column_default :attendance_policies, :close_after_minutes, from: 20, to: 90
  end
end
