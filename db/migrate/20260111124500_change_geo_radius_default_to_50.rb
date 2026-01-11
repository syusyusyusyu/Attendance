class ChangeGeoRadiusDefaultTo50 < ActiveRecord::Migration[8.0]
  def change
    change_column_default :attendance_policies, :geo_radius_m, from: 150, to: 50
  end
end
