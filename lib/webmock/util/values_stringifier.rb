class WebMock::Util::ValuesStringifier
  def self.stringify_values(value)
    case value
    when nil
      value
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
      value.to_s
    end
  end
end
