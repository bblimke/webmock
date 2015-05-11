module WebMock
  module Util
    class Headers
      class Normalizer
        def initialize(name, value)
          @name = name
          @value = value
        end

        def call
          [normalized_name, normalized_value]
        end

        private

        def normalized_name
          name.to_s.split(/_|-/).map { |segment| segment.capitalize }.join("-")
        end

        def normalized_value
          case value
          when Regexp then value
          when Array then (value.size == 1) ? value.first : value.map {|v| v.to_s}.sort
          else value.to_s
          end
        end

        attr_reader :name, :value
      end
    end
  end
end
