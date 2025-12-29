class CreateAttendanceRecords < ActiveRecord::Migration[8.0]
  def change
    create_table :attendance_records do |t|
      t.references :user, null: false, foreign_key: true
      t.references :school_class, null: false, foreign_key: true
      t.date :date, null: false
      t.string :status, null: false
      t.datetime :timestamp, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.jsonb :location, default: {}
      t.string :verification_method, null: false
      t.references :modified_by, foreign_key: { to_table: :users }
      t.datetime :modified_at
      t.text :notes

      t.timestamps
    end

    add_index :attendance_records, [:user_id, :school_class_id, :date], unique: true, name: "index_attendance_records_unique_day"
  end
end
