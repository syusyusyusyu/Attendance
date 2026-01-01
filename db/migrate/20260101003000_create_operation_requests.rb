class CreateOperationRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :operation_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.references :school_class, foreign_key: true
      t.string :kind, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :payload, null: false, default: {}
      t.text :reason
      t.text :decision_reason
      t.references :processed_by, foreign_key: { to_table: :users }
      t.datetime :processed_at
      t.timestamps
    end

    add_index :operation_requests, :status
    add_index :operation_requests, :kind
    add_index :operation_requests, :created_at
  end
end
