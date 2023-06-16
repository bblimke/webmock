require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/shared_test')

class TestWebMock < Test::Unit::TestCase
  include SharedTest

  def teardown
    # Ensure global Test::Unit teardown was called
    assert_empty WebMock::RequestRegistry.instance.requested_signatures.hash
    assert_empty WebMock::StubRegistry.instance.request_stubs
  end
end
