module WebMock::Util
  class QueryValueStringifier
    class << self
      def stringify(value)
        case value
        when String
          value
        when Array
          value.map { |v| stringify(v) }
        when Hash
          Hash[value.map { |k, v| [k, stringify(v)] }]
        else
          value.to_s
        end
      end
    end
  end
end
