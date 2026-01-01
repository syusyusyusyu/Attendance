require "test_helper"

class QrScanEventTest < ActiveSupport::TestCase
  test "requires status and token_digest" do
    event = QrScanEvent.new
    message = I18n.t("errors.messages.blank")

    assert_not event.valid?
    assert_includes event.errors[:status], message
    assert_includes event.errors[:token_digest], message
  end
end
