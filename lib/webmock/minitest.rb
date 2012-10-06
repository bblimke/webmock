require 'minitest/unit'
require 'webmock'

MiniTest::Unit::TestCase.class_eval do
  include WebMock::API

  alias_method :teardown_without_webmock, :teardown
  def teardown_with_webmock
    teardown_without_webmock
    WebMock.reset!
  end
  alias_method :teardown, :teardown_with_webmock

  [:assert_request_requested, :assert_request_not_requested].each do |name|
    alias_method :"#{name}_without_assertions_count", name
    define_method :"#{name}_with_assertions_count" do |*args|
      self._assertions += 1
      send :"#{name}_without_assertions_count", *args
    end
    alias_method name, :"#{name}_with_assertions_count"
  end
end

WebMock::AssertionFailure.error_class = MiniTest::Assertion
