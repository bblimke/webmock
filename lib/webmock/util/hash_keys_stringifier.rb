# frozen_string_literal: true

module WebMock
  module Util
    class HashKeysStringifier

      def self.stringify_keys!(arg, options = {})
        case arg
        when Array
          arg.map { |elem|
            options[:deep] ? stringify_keys!(elem, options) : elem
          }
        when Hash
          Hash[
            *arg.map { |key, value|
              k = key.is_a?(Symbol) ? key.to_s : key
              v = (options[:deep] ? stringify_keys!(value, options) : value)
              [k,v]
            }.inject([]) {|r,x| r + x}]
        else
          options[:deep] ? with_string_keys(arg) : arg
        end
      end

      # RSpec's hash_including and hash_excluding nested in a pattern keep
      # their keys as given, so they get string keys here, as do hashes in
      # array_including and array_excluding. They stay RSpec matchers, which
      # compare nested values the way RSpec does. A matcher without keys to
      # change is kept as it is.
      def self.with_string_keys(arg)
        # Defined in request_pattern.rb, which this file can be loaded without.
        return arg unless defined?(WebMock::RSpecMatcherDetector)

        name = if WebMock::RSpecMatcherDetector.rSpecHashMatcher?(arg)
          :@expected
        elsif WebMock::RSpecMatcherDetector.rSpecArrayMatcher?(arg)
          arg.instance_variable_defined?(:@expected) ? :@expected : :@unexpected
        end
        return arg unless name

        expected = arg.instance_variable_get(name)
        converted = stringify_keys!(expected, deep: true)
        converted == expected ? arg : arg.class.new(converted)
      end
      private_class_method :with_string_keys

    end
  end
end
