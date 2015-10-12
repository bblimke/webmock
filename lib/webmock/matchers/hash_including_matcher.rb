module WebMock
  module Matchers
    #this is a based on RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher
    #https://github.com/rspec/rspec-mocks/blob/master/lib/rspec/mocks/argument_matchers.rb
    class HashIncludingMatcher
      def initialize(expected)
        @expected = Hash[WebMock::Util::HashKeysStringifier.stringify_keys!(expected, :deep => true).sort]
      end

      def ==(actual)
        @expected.all? do |k,v|
          actual_value = actual.respond_to?(:has_key?) ? actual[k] : actual
          actual_value = WebMock::Util::QueryValueStringifier.stringify(actual_value)
          actual.has_key?(k) && WebMock::Util::QueryValueStringifier.stringify(v) === actual_value
       end

      rescue NoMethodError
        false
      end

      def inspect
        "hash_including(#{@expected.inspect})"
      end

      def self.from_rspec_matcher(matcher)
        new(matcher.instance_variable_get(:@expected))
      end
    end

    #this is a based on RSpec::Mocks::ArgumentMatchers::AnyArgMatcher
    class AnyArgMatcher
      def initialize(ignore)
      end

      def ==(other)
        true
      end
    end

  end
end
