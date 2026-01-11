class AddGeoAddressToAttendancePolicies < ActiveRecord::Migration[8.0]
  def change
    add_column :attendance_policies, :geo_address, :string
  end
end
