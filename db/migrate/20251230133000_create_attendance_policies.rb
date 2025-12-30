class CreateAttendancePolicies < ActiveRecord::Migration[8.0]
  def change
    create_table :attendance_policies do |t|
      t.references :school_class, null: false, foreign_key: true, index: { unique: true }
      t.integer :late_after_minutes, null: false, default: 10
      t.integer :close_after_minutes, null: false, default: 90
      t.boolean :allow_early_checkin, null: false, default: true
      t.timestamps
    end
  end
end
