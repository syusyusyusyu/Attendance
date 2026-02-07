require "test_helper"

class LineNotifierTest < ActiveSupport::TestCase
  setup do
    @notifier = LineNotifier.new(channel_token: "test-channel-token")
  end

  test "push sends POST request to LINE API" do
    stub_request = nil

    Net::HTTP.stub(:start, ->(host, port, use_ssl:, &block) {
      stub_request = { host: host, port: port, ssl: use_ssl }
      response = Net::HTTPSuccess.allocate
      response.define_singleton_method(:code) { "200" }
      response.define_singleton_method(:body) { "{}" }
      response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPSuccess }
      block.call(OpenStruct.new(request: ->(req) { stub_request[:request] = req; response }))
    }) do
      @notifier.push(user_id: "U1234", message: "テストメッセージ")
    end

    assert_equal "api.line.me", stub_request[:host]
    assert stub_request[:ssl]
  end

  test "push skips when user_id is blank" do
    Net::HTTP.stub(:start, ->(*) { raise "should not call HTTP" }) do
      @notifier.push(user_id: "", message: "テスト")
    end
  end

  test "push skips when message is blank" do
    Net::HTTP.stub(:start, ->(*) { raise "should not call HTTP" }) do
      @notifier.push(user_id: "U1234", message: "")
    end
  end

  test "push logs warning on HTTP error without raising" do
    error_response = Object.new
    error_response.define_singleton_method(:is_a?) { |klass| klass == Net::HTTPSuccess ? false : super(klass) }
    error_response.define_singleton_method(:code) { "400" }
    error_response.define_singleton_method(:body) { "Bad Request" }

    fake_http = Object.new
    fake_http.define_singleton_method(:request) { |_req| error_response }

    Net::HTTP.stub(:start, ->(*, **, &block) { block.call(fake_http) }) do
      assert_nothing_raised do
        @notifier.push(user_id: "U1234", message: "テスト")
      end
    end
  end

  test "push rescues network errors without raising" do
    Net::HTTP.stub(:start, ->(*) { raise Errno::ECONNREFUSED }) do
      assert_nothing_raised do
        @notifier.push(user_id: "U1234", message: "テスト")
      end
    end
  end
end
