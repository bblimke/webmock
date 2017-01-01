require 'test/unit'
require 'webmock'

WebMock.enable!

module Test
  module Unit
    class TestCase
      include WebMock::API

      alias_method :teardown_without_webmock, :teardown
      def teardown_with_webmock
        teardown_without_webmock
        WebMock.reset!
      end
      alias_method :teardown, :teardown_with_webmock

    end
  end
end

WebMock::AssertionFailure.error_class = Test::Unit::AssertionFailedError
