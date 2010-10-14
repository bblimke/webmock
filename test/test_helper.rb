require 'rubygems'
require 'bundler'
Bundler.setup(:default)

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'webmock/test_unit'
require 'test/unit'

class Test::Unit::TestCase
  include WebMock::API
  AssertionFailedError =  Test::Unit::AssertionFailedError rescue MiniTest::Assertion
  def assert_fail(message, &block)
    e = assert_raise(AssertionFailedError, &block)
    assert_equal(message, e.message)
  end
end
