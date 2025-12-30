require "test_helper"

class QrScanEventTest < ActiveSupport::TestCase
  test "requires status and token_digest" do
    event = QrScanEvent.new

    assert_not event.valid?
    assert_includes event.errors[:status], "can't be blank"
    assert_includes event.errors[:token_digest], "can't be blank"
  end
end
