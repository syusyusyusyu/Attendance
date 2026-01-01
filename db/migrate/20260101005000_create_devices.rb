class CreateDevices < ActiveRecord::Migration[8.0]
  def change
    create_table :devices do |t|
      t.references :user, null: false, foreign_key: true
      t.string :device_id, null: false
      t.string :name
      t.string :user_agent
      t.string :ip
      t.boolean :approved, null: false, default: false
      t.datetime :last_seen_at
      t.timestamps
    end

    add_index :devices, [:user_id, :device_id], unique: true
    add_index :devices, :approved
  end
end
