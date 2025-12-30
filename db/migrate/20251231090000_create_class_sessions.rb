class CreateClassSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :class_sessions do |t|
      t.references :school_class, null: false, foreign_key: true
      t.date :date, null: false
      t.datetime :start_at
      t.datetime :end_at
      t.string :status, null: false, default: "regular"
      t.datetime :locked_at
      t.text :note
      t.timestamps
    end

    add_index :class_sessions, [:school_class_id, :date], unique: true
    add_index :class_sessions, :date
    add_index :class_sessions, :status
  end
end
