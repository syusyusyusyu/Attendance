class AddAttendanceStatusToQrScanEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :qr_scan_events, :attendance_status, :string
    add_index :qr_scan_events, :attendance_status
  end
end
