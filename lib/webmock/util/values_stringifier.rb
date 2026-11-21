# frozen_string_literal: true

class WebMock::Util::ValuesStringifier
  def self.stringify_values(value)
    case value
    when String, Numeric, TrueClass, FalseClass
      value.to_s
    when Hash
      Hash[
        value.map do |k, v|
          [k, stringify_values(v)]
        end
      ]
    when Array
      value.map do |v|
        stringify_values(v)
      end
    else
      value
    end
  end

  # Like stringify_values, for query patterns: also converts the values of
  # nested hash_including and hash_excluding matchers. Strings are kept as
  # given, so a String subclass keeps its own ===.
  def self.stringify_query_values(value)
    case value
    when WebMock::Matchers::HashArgumentMatcher
      # A copy, so a subclass keeps its own constructor and state.
      value.dup.tap do |matcher|
        matcher.instance_variable_set(:@expected, stringify_query_values(value.instance_variable_get(:@expected)))
      end
    when Hash
      Hash[value.map { |k, v| [k, stringify_query_values(v)] }]
    when Array
      value.map { |v| stringify_query_values(v) }
    when String
      value
    else
      if WebMock::RSpecMatcherDetector.rSpecHashMatcher?(value)
        expected = stringify_query_values(value.instance_variable_get(:@expected))
        NestedRSpecMatcher.new(value.class.new(expected))
      else
        stringify_values(value)
      end
    end
  end

  # Keeps RSpec's comparison of nested values, such as an array of regexps,
  # and adds ==, which a query Hash uses to compare its values.
  class NestedRSpecMatcher
    def initialize(matcher)
      @matcher = matcher
    end

    def ===(actual)
      @matcher === actual
    end
    alias == ===

    def inspect
      @matcher.description
    end
  end

  # Whether a query pattern holds a matcher, so it can't be written into
  # a URL.
  def self.includes_query_matcher?(value)
    case value
    when Hash then value.each_value.any? { |v| includes_query_matcher?(v) }
    when Array then value.any? { |v| includes_query_matcher?(v) }
    when WebMock::Matchers::HashArgumentMatcher, NestedRSpecMatcher then true
    else false
    end
  end
end
