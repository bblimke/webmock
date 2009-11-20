$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'test/unit'
require 'webmock'

def assert_fail(message, &block)
  e = assert_raise(Test::Unit::AssertionFailedError, &block)
  assert_equal(message, e.message)
end