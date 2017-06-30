module WebMock
  module Matchers
    # this is a based on RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher
    # https://github.com/rspec/rspec-mocks/blob/master/lib/rspec/mocks/argument_matchers.rb
    class HashIncludingMatcher < HashArgumentMatcher
      def ==(actual)
        super do |key, value|
          case value
          when Array
            zipped = value.zip(actual[key])
            zipped.any? { |expected, actual| HashIncludingMatcher.new(expected) === actual }
          when Hash
            HashIncludingMatcher.new(value) === actual[key]
          else
            actual.key?(key) && value === actual[key]
          end
        end
      rescue NoMethodError
        false
      end

      def inspect
        "hash_including(#{@expected.inspect})"
      end
    end
  end
end
