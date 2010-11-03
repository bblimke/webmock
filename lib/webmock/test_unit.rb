require 'test/unit'
require 'webmock'

module Test
  module Unit
    class TestCase
      include WebMock::API

      alias_method :setup_without_webmock, :setup
      def setup_with_webmock
        setup_without_webmock
        WebMock.reset!
      end
      alias_method :setup, :setup_with_webmock

    end
  end
end

WebMock::AssertionFailure.error_class = Test::Unit::AssertionFailedError rescue MiniTest::Assertion # ruby1.9 compat
