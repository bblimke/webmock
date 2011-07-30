require 'rubygems'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

gem "minitest"
require 'minitest/autorun'
require 'webmock/minitest'

class MiniTest::Unit::TestCase
  def assert_raise(*exp, &block)
    assert_raises(*exp, &block)
  end
  AssertionFailedError =  MiniTest::Assertion
  def assert_fail(message, &block)
    e = assert_raises(AssertionFailedError, &block)
    if message.is_a?(Regexp)
      assert_match(message, e.message)
    else
      assert_equal(message, e.message)
    end
  end
end