class QrScanRateLimiter
  def initialize(cache: Rails.cache, user_id:, class_id: nil, now: Time.current)
    @cache = cache
    @user_id = user_id
    @class_id = class_id
    @now = now
  end

  def user_limited?(limit:)
    return false if limit.to_i <= 0

    key = "qr_scan:user:#{@user_id}:#{@now.strftime('%Y%m%d%H%M')}"
    count = @cache.increment(key, 1, expires_in: 60)
    count.present? && count > limit
  end

  def class_limited?(limit:)
    return false if @class_id.blank? || limit.to_i <= 0

    key = "qr_scan:class:#{@class_id}:#{@now.strftime('%Y%m%d%H%M')}"
    count = @cache.increment(key, 1, expires_in: 60)
    count.present? && count > limit
  end
end
