require "test_helper"

class AttendanceChangeTest < ActiveSupport::TestCase
  test "requires date, new_status, changed_at, and reason" do
    change = AttendanceChange.new
    message = I18n.t("errors.messages.blank")

    assert_not change.valid?
    assert_includes change.errors[:date], message
    assert_includes change.errors[:new_status], message
    assert_includes change.errors[:changed_at], message
    assert_includes change.errors[:reason], message
  end
end
