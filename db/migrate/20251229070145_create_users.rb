class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false
      t.string :student_id
      t.string :profile_image
      t.jsonb :settings, null: false, default: {
        notifications: { email: true, push: false },
        theme: "light",
        language: "ja"
      }
      t.string :password_digest, null: false
      t.datetime :last_login

      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :student_id, unique: true
  end
end
