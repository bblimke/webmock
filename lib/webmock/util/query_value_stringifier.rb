module WebMock::Util
  class QueryValueStringifier
    class << self
      def stringify(value)
        case value
        when String, NilClass
          value
        when Array
          value.map { |v| stringify(v) }
        when Hash
          Hash[value.map { |k, v| [k, stringify(v)] }]
        when Integer, TrueClass, FalseClass, Symbol
          value.to_s
        when WebMock::Matchers::AnyArgMatcher, RSpec::Mocks::ArgumentMatchers::AnyArgMatcher
          value
        else
          value
        end
      end
    end
  end
end
