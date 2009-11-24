require 'rubygems'

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'webmock/test_unit'
require 'test/unit'
include WebMock

def assert_fail(message, &block)
  e = assert_raise(Test::Unit::AssertionFailedError, &block)
  assert_equal(message, e.message)
end