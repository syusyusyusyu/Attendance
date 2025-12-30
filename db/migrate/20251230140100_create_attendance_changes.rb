class CreateAttendanceChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :attendance_changes do |t|
      t.references :attendance_record, foreign_key: true
      t.references :user, foreign_key: true
      t.references :school_class, foreign_key: true
      t.date :date, null: false
      t.string :previous_status
      t.string :new_status, null: false
      t.text :reason
      t.references :modified_by, foreign_key: { to_table: :users }
      t.string :source, null: false, default: "manual"
      t.string :ip
      t.string :user_agent
      t.datetime :changed_at, null: false
      t.timestamps
    end

    add_index :attendance_changes, :changed_at
  end
end
