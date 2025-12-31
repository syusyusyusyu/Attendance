class ClassSessionResolver
  def initialize(school_class:, date:)
    @school_class = school_class
    @date = date
  end

  def resolve
    schedule = @school_class.schedule || {}
    override = @school_class.class_session_overrides.find_by(date: @date)

    day_index = schedule["day_of_week"] || schedule[:day_of_week]
    period = schedule["period"] || schedule[:period]
    period_times = SchoolClass.period_times(period) if period.present?
    start_time = override&.start_time || schedule["start_time"] || schedule[:start_time] || period_times&.fetch(:start, nil)
    end_time = override&.end_time || schedule["end_time"] || schedule[:end_time] || period_times&.fetch(:end, nil)

    return nil if override.nil? && (day_index.blank? || start_time.blank? || end_time.blank?)
    return nil if override.nil? && day_index.to_i != @date.wday

    status = override&.status || "regular"
    start_at = parse_time(@date, start_time) if start_time.present?
    end_at = parse_time(@date, end_time) if end_time.present?

    if start_at.present? && end_at.present? && end_at <= start_at
      end_at += 1.day
    end

    session = @school_class.class_sessions.find_or_initialize_by(date: @date)
    session.status = status
    session.start_at = start_at
    session.end_at = end_at
    session.note = override&.note
    session.save! if session.changed?

    { session: session, override: override }
  end

  private

  def parse_time(date, time_str)
    Time.zone.parse("#{date} #{time_str}")
  end
end
