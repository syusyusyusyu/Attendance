class CreateClassSessionOverrides < ActiveRecord::Migration[8.0]
  def change
    create_table :class_session_overrides do |t|
      t.references :school_class, null: false, foreign_key: true
      t.date :date, null: false
      t.string :start_time
      t.string :end_time
      t.string :status, null: false, default: "regular"
      t.text :note
      t.timestamps
    end

    add_index :class_session_overrides, [:school_class_id, :date], unique: true
    add_index :class_session_overrides, :status
  end
end
