class EnforceOicGeoForAttendancePolicies < ActiveRecord::Migration[8.0]
  OIC_GEO = {
    postal_code: "543-0001",
    address: "大阪府大阪市天王寺区上本町6-8-4",
    lat: 34.663692,
    lng: 135.518692,
    radius_m: 50
  }.freeze

  def up
    AttendancePolicy.update_all(
      require_location: true,
      geo_fence_enabled: true,
      geo_radius_m: OIC_GEO[:radius_m],
      geo_postal_code: OIC_GEO[:postal_code],
      geo_address: OIC_GEO[:address],
      geo_center_lat: OIC_GEO[:lat],
      geo_center_lng: OIC_GEO[:lng]
    )
  end

  def down
    # OIC固定の運用方針のため、ロールバック時も変更しません。
  end
end
