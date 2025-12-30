class CreateQrSessionsAndScanEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :qr_sessions do |t|
      t.references :school_class, null: false, foreign_key: true
      t.references :teacher, null: false, foreign_key: { to_table: :users }
      t.date :attendance_date, null: false
      t.datetime :issued_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :qr_sessions, [:school_class_id, :attendance_date]
    add_index :qr_sessions, :expires_at

    create_table :qr_scan_events do |t|
      t.references :qr_session, foreign_key: true
      t.references :user, foreign_key: true
      t.references :school_class, foreign_key: true
      t.string :status, null: false
      t.string :token_digest, null: false
      t.string :ip
      t.string :user_agent
      t.datetime :scanned_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end

    add_index :qr_scan_events, :status
    add_index :qr_scan_events, :token_digest
  end
end
