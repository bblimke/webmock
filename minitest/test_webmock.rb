require File.expand_path(File.dirname(__FILE__) + '/test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../test/shared_test')

test_class = defined?(MiniTest::Test) ? MiniTest::Test : MiniTest::Unit::TestCase


class MiniTestWebMock < test_class
  include SharedTest
end
