class CreateSchoolClasses < ActiveRecord::Migration[8.0]
  def change
    create_table :school_classes do |t|
      t.string :name, null: false
      t.references :teacher, null: false, foreign_key: { to_table: :users }
      t.string :room, null: false
      t.string :subject, null: false
      t.string :semester, null: false
      t.integer :year, null: false
      t.integer :capacity, null: false, default: 40
      t.text :description
      t.jsonb :schedule, null: false, default: {}
      t.boolean :is_active, null: false, default: true

      t.timestamps
    end
  end
end
