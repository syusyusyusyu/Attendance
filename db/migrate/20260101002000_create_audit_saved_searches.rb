class CreateAuditSavedSearches < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_saved_searches do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :scope, null: false, default: "audit"
      t.text :query
      t.jsonb :filters, null: false, default: {}
      t.boolean :is_default, null: false, default: false
      t.timestamps
    end

    add_index :audit_saved_searches, [:user_id, :scope, :name], unique: true
    add_index :audit_saved_searches, [:user_id, :scope, :is_default]
  end
end
