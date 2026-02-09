class AddNotNullToReasonColumns < ActiveRecord::Migration[8.0]
  def up
    change_column_null :attendance_changes, :reason, false
    change_column_null :attendance_requests, :reason, false
  end

  def down
    change_column_null :attendance_changes, :reason, true
    change_column_null :attendance_requests, :reason, true
  end
end
