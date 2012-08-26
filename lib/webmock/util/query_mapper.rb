module WebMock::Util
  class QueryMapper
    #This class is based on Addressable::URI pre 2.3.0

    ##
    # Converts the query component to a Hash value.
    #
    # @option [Symbol] notation
    #   May be one of <code>:flat</code>, <code>:dot</code>, or
    #   <code>:subscript</code>. The <code>:dot</code> notation is not
    #   supported for assignment. Default value is <code>:subscript</code>.
    #
    # @return [Hash, Array] The query string parsed as a Hash or Array object.
    #
    # @example
    #   WebMock::Util::QueryMapper.query_to_values("?one=1&two=2&three=3")
    #   #=> {"one" => "1", "two" => "2", "three" => "3"}
    #   WebMock::Util::QueryMapper("?one[two][three]=four").query_values
    #   #=> {"one" => {"two" => {"three" => "four"}}}
    #   WebMock::Util::QueryMapper.query_to_values("?one.two.three=four",
    #     :notation => :dot
    #   )
    #   #=> {"one" => {"two" => {"three" => "four"}}}
    #   WebMock::Util::QueryMapper.query_to_values("?one[two][three]=four",
    #     :notation => :flat
    #   )
    #   #=> {"one[two][three]" => "four"}
    #   WebMock::Util::QueryMapper.query_to_values("?one.two.three=four",
    #     :notation => :flat
    #   )
    #   #=> {"one.two.three" => "four"}
    #   WebMock::Util::QueryMapper(
    #     "?one[two][three][]=four&one[two][three][]=five"
    #   )
    #   #=> {"one" => {"two" => {"three" => ["four", "five"]}}}
    #   WebMock::Util::QueryMapper.query_to_values(
    #     "?one=two&one=three").query_values(:notation => :flat_array)
    #   #=> [['one', 'two'], ['one', 'three']]
    def self.query_to_values(query, options={})
      defaults = {:notation => :subscript}
      options = defaults.merge(options)
      if ![:flat, :dot, :subscript, :flat_array].include?(options[:notation])
        raise ArgumentError,
          "Invalid notation. Must be one of: " +
          "[:flat, :dot, :subscript, :flat_array]."
      end
      dehash = lambda do |hash|
        hash.each do |(key, value)|
          if value.kind_of?(Hash)
            hash[key] = dehash.call(value)
          end
        end
        if hash != {} && hash.keys.all? { |key| key =~ /^\d+$/ }
          hash.sort.inject([]) do |accu, (_, value)|
            accu << value; accu
          end
        else
          hash
        end
      end
      return nil if query == nil
      empty_accumulator = :flat_array == options[:notation] ? [] : {}
      return ((query.split("&").map do |pair|
                 pair.split("=", 2) if pair && !pair.empty?
              end).compact.inject(empty_accumulator.dup) do |accumulator, (key, value)|
                value = true if value.nil?
                key = Addressable::URI.unencode_component(key)
                if value != true
                  value = Addressable::URI.unencode_component(value.gsub(/\+/, " "))
                end
                if options[:notation] == :flat
                  if accumulator[key]
                    raise ArgumentError, "Key was repeated: #{key.inspect}"
                  end
                  accumulator[key] = value
                elsif options[:notation] == :flat_array
                  accumulator << [key, value]
                else
                  if options[:notation] == :dot
                    array_value = false
                    subkeys = key.split(".")
                  elsif options[:notation] == :subscript
                    array_value = !!(key =~ /\[\]$/)
                    subkeys = key.split(/[\[\]]+/)
                  end
                  current_hash = accumulator
                  for i in 0...(subkeys.size - 1)
                    subkey = subkeys[i]
                    current_hash[subkey] = {} unless current_hash[subkey]
                    current_hash = current_hash[subkey]
                  end
                  if array_value
                    current_hash[subkeys.last] = [] unless current_hash[subkeys.last]
                    current_hash[subkeys.last] << value
                  else
                    current_hash[subkeys.last] = value
                  end
                end
                accumulator
      end).inject(empty_accumulator.dup) do |accumulator, (key, value)|
        if options[:notation] == :flat_array
          accumulator << [key, value]
        else
          accumulator[key] = value.kind_of?(Hash) ? dehash.call(value) : value
        end
        accumulator
      end
    end

    ##
    # Sets the query component for this URI from a Hash object.
    # This method produces a query string using the :subscript notation.
    # An empty Hash will result in a nil query.
    #
    # @param [Hash, #to_hash, Array] new_query_values The new query values.
    def self.values_to_query(new_query_values)
      if new_query_values == nil
        return nil
      end

      if !new_query_values.is_a?(Array)
        if !new_query_values.respond_to?(:to_hash)
          raise TypeError,
            "Can't convert #{new_query_values.class} into Hash."
        end
        new_query_values = new_query_values.to_hash
        new_query_values = new_query_values.map do |key, value|
          key = key.to_s if key.kind_of?(Symbol)
          [key, value]
        end
        # Useful default for OAuth and caching.
        # Only to be used for non-Array inputs. Arrays should preserve order.
        new_query_values.sort!
      end

      ##
      # Joins and converts parent and value into a properly encoded and
      # ordered URL query.
      #
      # @private
      # @param [String] parent an URI encoded component.
      # @param [Array, Hash, Symbol, #to_str] value
      #
      # @return [String] a properly escaped and ordered URL query.
      to_query = lambda do |parent, value|
        if value.is_a?(Hash)
          value = value.map do |key, val|
            [
              Addressable::URI.encode_component(key, Addressable::URI::CharacterClasses::UNRESERVED),
              val
            ]
          end
          value.sort!
          buffer = ""
          value.each do |key, val|
            new_parent = "#{parent}[#{key}]"
            buffer << "#{to_query.call(new_parent, val)}&"
          end
          return buffer.chop
        elsif value.is_a?(Array)
          buffer = ""
          value.each_with_index do |val, i|
            new_parent = "#{parent}[#{i}]"
            buffer << "#{to_query.call(new_parent, val)}&"
          end
          return buffer.chop
        elsif value == true
          return parent
        else
          encoded_value = Addressable::URI.encode_component(
            value, Addressable::URI::CharacterClasses::UNRESERVED
          )
          return "#{parent}=#{encoded_value}"
        end
      end

      # new_query_values have form [['key1', 'value1'], ['key2', 'value2']]
      buffer = ""
      new_query_values.each do |parent, value|
        encoded_parent = Addressable::URI.encode_component(
          parent, Addressable::URI::CharacterClasses::UNRESERVED
        )
        buffer << "#{to_query.call(encoded_parent, value)}&"
      end
      return buffer.chop
    end
  end
end
