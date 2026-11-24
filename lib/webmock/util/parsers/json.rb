# frozen_string_literal: true

# parse_legacy is a copy of https://github.com/jnunemaker/crack/blob/master/lib/crack/json.rb
# with date parsing removed
# Copyright (c) 2004-2008 David Heinemeier Hansson
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require "json"
require_relative "parse_error"

module WebMock
  module Util
    module Parsers
      class JSON
        # Deep enough for any real body, and shallow enough for every json
        # gem version to parse in a thread's stack.
        MAX_NESTING = 1000

        def self.parse(json)
          # JSON texts may start with a byte order mark, which parsers may ignore.
          json = to_utf8(json).delete_prefix("\uFEFF")
          ::JSON.parse(json, allow_duplicate_key: true, max_nesting: MAX_NESTING)
        rescue ::JSON::JSONError, EncodingError => e
          raise ParseError, "Invalid JSON string: #{e.message}"
        end

        # The YAML based parser WebMock used up to 3.40.0. It reads some
        # bodies that aren't valid JSON, such as {a: 1}, and some values
        # differently from the json gem, such as 1e+20 as a String.
        # WebMock 4.0 drops it.
        def self.parse_legacy(json)
          yaml = unescape(convert_json_to_yaml(json))
          YAML.load(yaml)
        rescue ArgumentError, EncodingError, Psych::Exception => e
          raise ParseError, "Invalid JSON string: #{yaml}, Error: #{e.inspect}"
        end

        # The json gem reads bytes that aren't valid in their encoding, so
        # such a body, for example a binary upload, is rejected here. A
        # binary or US-ASCII string, as read from a socket or from a file in
        # a C locale, is taken as UTF-8.
        def self.to_utf8(json)
          if json.encoding == Encoding::BINARY || json.encoding == Encoding::US_ASCII
            json = json.dup.force_encoding(Encoding::UTF_8)
          end
          raise ParseError, "Invalid JSON string: it isn't valid #{json.encoding}" unless json.valid_encoding?

          json.encoding == Encoding::UTF_8 ? json : json.encode(Encoding::UTF_8)
        end
        private_class_method :to_utf8

        protected

        def self.unescape(str)
          str.gsub(/\\u([0-9a-f]{4})/) { [$1.hex].pack("U") }
        end

        # Ensure that ":" and "," are always followed by a space
        def self.convert_json_to_yaml(json) #:nodoc:
          scanner, quoting, marks, times = StringScanner.new(json), false, [], []
          while scanner.scan_until(/(\\['"]|['":,\\]|\\.)/)
            case char = scanner[1]
            when '"', "'"
              if !quoting
                quoting = char
              elsif quoting == char
                quoting = false
              end
            when ":",","
                marks << scanner.pos - 1 unless quoting
            when "\\"
                scanner.skip(/\\/)
            end
          end

          if marks.empty?
            json.gsub(/\\\//, '/')
          else
            left_pos  = [-1].push(*marks)
            right_pos = marks << json.bytesize
            output    = []

            left_pos.each_with_index do |left, i|
              if json.respond_to?(:byteslice)
                output << json.byteslice(left.succ..right_pos[i])
              else
                output << json[left.succ..right_pos[i]]
              end
            end

            output = output * " "

            times.each { |i| output[i-1] = ' ' }
            output.gsub!(/\\\//, '/')
            output
          end
        end
      end
    end
  end
end