class RemoveDeviceManagement < ActiveRecord::Migration[8.0]
  def change
    drop_table :devices, if_exists: true
    remove_column :attendance_policies, :require_registered_device, :boolean if column_exists?(:attendance_policies, :require_registered_device)
  end
end
