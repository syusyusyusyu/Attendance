class CreateAttendanceRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :attendance_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :school_class, null: false, foreign_key: true
      t.references :class_session, foreign_key: true
      t.date :date, null: false
      t.string :request_type, null: false
      t.string :status, null: false, default: "pending"
      t.text :reason
      t.datetime :submitted_at, null: false
      t.bigint :processed_by_id
      t.datetime :processed_at
      t.text :decision_reason
      t.timestamps
    end

    add_index :attendance_requests, :status
    add_index :attendance_requests, [:school_class_id, :date]
    add_index :attendance_requests, [:user_id, :date]
    add_index :attendance_requests, :processed_by_id
    add_foreign_key :attendance_requests, :users, column: :processed_by_id
  end
end
