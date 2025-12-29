class CreateEnrollments < ActiveRecord::Migration[8.0]
  def change
    create_table :enrollments do |t|
      t.references :school_class, null: false, foreign_key: true
      t.references :student, null: false, foreign_key: { to_table: :users }
      t.datetime :enrolled_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps
    end

    add_index :enrollments, [:school_class_id, :student_id], unique: true
  end
end
