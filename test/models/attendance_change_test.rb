require "test_helper"

class AttendanceChangeTest < ActiveSupport::TestCase
  test "requires date, new_status, and changed_at" do
    change = AttendanceChange.new

    assert_not change.valid?
    assert_includes change.errors[:date], "can't be blank"
    assert_includes change.errors[:new_status], "can't be blank"
    assert_includes change.errors[:changed_at], "can't be blank"
  end
end
