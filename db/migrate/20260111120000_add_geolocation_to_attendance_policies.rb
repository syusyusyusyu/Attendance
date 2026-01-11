class AddGeolocationToAttendancePolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :attendance_policies, :require_location, :boolean, default: true, null: false
    add_column :attendance_policies, :geo_fence_enabled, :boolean, default: false, null: false
    add_column :attendance_policies, :geo_center_lat, :decimal, precision: 10, scale: 6
    add_column :attendance_policies, :geo_center_lng, :decimal, precision: 10, scale: 6
    add_column :attendance_policies, :geo_radius_m, :integer, default: 150, null: false
    add_column :attendance_policies, :geo_accuracy_max_m, :integer, default: 150, null: false
  end
end
