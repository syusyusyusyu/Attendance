require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  self.use_transactional_tests = false
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]
end
