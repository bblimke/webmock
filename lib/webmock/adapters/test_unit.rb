require 'test/unit'
require 'webmock'

class Test::Unit::TestCase
  alias setup_without_webmock setup
  def setup
    WebMock.reset_webmock
    @original_allow_net_connect = WebMock.net_connect_allowed?
    WebMock.disable_net_connect!
  end

  alias teardown_without_webmock teardown
  def teardown
    @original_allow_net_connect ? WebMock.allow_net_connect! : WebMock.disable_net_connect!
  end
end

module WebMock
  AssertionFailedError = Test::Unit::AssertionFailedError rescue MiniTest::Assertion # ruby1.9 compat
  def assertion_failure(message)
    raise AssertionFailedError.new(message)
  end
end

