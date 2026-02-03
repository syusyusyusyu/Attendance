class AddDemoModeToQrSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :qr_sessions, :demo_mode, :boolean, default: false, null: false
  end
end
