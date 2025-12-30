class AddSessionFieldsToAttendanceRecords < ActiveRecord::Migration[8.0]
  def change
    add_reference :attendance_records, :class_session, foreign_key: true
    add_column :attendance_records, :checked_in_at, :datetime
    add_column :attendance_records, :checked_out_at, :datetime
    add_column :attendance_records, :duration_minutes, :integer
  end
end
