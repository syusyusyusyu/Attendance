class AttendancePolicy
  class Geo
    EARTH_RADIUS_M = 6_371_000.0

    def initialize(policy)
      @policy = policy
    end

    def validate(location:)
      normalized = normalize(location)

      if required? && normalized.blank?
        return failure("location_required", "位置情報の取得が必要です。ブラウザの位置情報を許可してください。")
      end

      return success if normalized.blank?

      if normalized[:latitude].nil? || normalized[:longitude].nil?
        return failure("location_invalid", "位置情報が正しく取得できません。位置情報を許可して再試行してください。")
      end

      if accuracy_too_low?(normalized[:accuracy])
        return failure("location_inaccurate", "位置情報の精度が低いため登録できません。屋外で再試行してください。")
      end

      if geofence_enabled?
        distance = distance_m(
          normalized[:latitude],
          normalized[:longitude],
          @policy.geo_center_lat,
          @policy.geo_center_lng
        )

        if distance > @policy.geo_radius_m.to_f
          return failure("location_outside", "教室付近でスキャンしてください。")
        end
      end

      success(location: normalized)
    end

    def required?
      @policy.require_location
    end

    def geofence_enabled?
      @policy.geo_fence_enabled && center_present? && @policy.geo_radius_m.to_i.positive?
    end

    private

    def normalize(location)
      return nil if location.blank?

      {
        latitude: parse_float(location[:latitude] || location["latitude"]),
        longitude: parse_float(location[:longitude] || location["longitude"]),
        accuracy: parse_float(location[:accuracy] || location["accuracy"]),
        source: location[:source] || location["source"]
      }
    end

    def accuracy_too_low?(accuracy)
      max_accuracy = @policy.geo_accuracy_max_m.to_i
      return false if max_accuracy <= 0
      return false if accuracy.nil?

      accuracy > max_accuracy
    end

    def center_present?
      @policy.geo_center_lat.present? && @policy.geo_center_lng.present?
    end

    def distance_m(lat1, lng1, lat2, lng2)
      lat1_rad = to_radians(lat1)
      lat2_rad = to_radians(lat2)
      dlat = lat2_rad - lat1_rad
      dlng = to_radians(lng2) - to_radians(lng1)

      a = Math.sin(dlat / 2)**2 +
          Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlng / 2)**2
      2 * EARTH_RADIUS_M * Math.asin(Math.sqrt(a))
    end

    def to_radians(value)
      value.to_f * Math::PI / 180.0
    end

    def parse_float(value)
      return nil if value.nil?

      Float(value)
    rescue ArgumentError, TypeError
      nil
    end

    def success(location: nil)
      { allowed: true, location: location }
    end

    def failure(status, message)
      { allowed: false, status: status, message: message }
    end
  end
end
