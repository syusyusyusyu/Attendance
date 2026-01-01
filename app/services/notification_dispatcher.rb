class NotificationDispatcher
  def initialize(notification)
    @notification = notification
    @user = notification.user
  end

  def deliver
    deliver_email if email_enabled?
    deliver_line if line_enabled?
    deliver_push if push_enabled?
  end

  def action_url
    return nil if @notification.action_path.blank?

    return @notification.action_path if @notification.action_path.start_with?("http")

    base = base_url
    base ? "#{base}#{@notification.action_path}" : @notification.action_path
  end

  private

  def preferences
    @user.notification_preferences
  end

  def email_enabled?
    preferences["email"] && @user.email.present? && ENV["SENDGRID_API_KEY"].present?
  end

  def line_enabled?
    preferences["line"] && @user.line_user_id.present? && ENV["LINE_CHANNEL_ACCESS_TOKEN"].present?
  end

  def push_enabled?
    preferences["push"] &&
      @user.push_subscriptions.exists? &&
      ENV["WEBPUSH_PUBLIC_KEY"].present? &&
      ENV["WEBPUSH_PRIVATE_KEY"].present?
  end

  def deliver_email
    NotificationMailer.alert(@notification, action_url: action_url).deliver_now
  end

  def deliver_line
    LineNotifier.new(channel_token: ENV.fetch("LINE_CHANNEL_ACCESS_TOKEN")).push(
      user_id: @user.line_user_id,
      message: line_message
    )
  end

  def deliver_push
    PushNotifier.new(@notification, action_url: action_url).deliver
  end

  def line_message
    base = @notification.body.presence || "通知があります。"
    url = action_url
    url.present? ? "#{@notification.title}\n#{base}\n#{url}" : "#{@notification.title}\n#{base}"
  end

  def base_url
    host = ENV["APP_HOST"].presence || ENV["RENDER_EXTERNAL_HOSTNAME"].presence
    return nil if host.blank?

    host.start_with?("http") ? host : "https://#{host}"
  end
end
