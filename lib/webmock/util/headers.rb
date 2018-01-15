require 'base64'

module WebMock

  module Util

    class Headers

      def self.normalize_headers(headers)
        return nil unless headers
        array = headers.map { |name, value|
          [name.to_s.split(/_|-/).map { |segment| segment.capitalize }.join("-"),
           case value
            when Regexp then value
            when Array then (value.size == 1) ? value.first.to_s : value.map {|v| v.to_s}.sort
            else value.to_s
           end
          ]
        }
        Hash[*array.inject([]) {|r,x| r + x}]
      end

      def self.sorted_headers_string(headers)
        headers = WebMock::Util::Headers.normalize_headers(headers)
        str = '{'.dup
        str << headers.map do |k,v|
          v = case v
            when Regexp then v.inspect
            when Array then "["+v.map{|w| "'#{w.to_s}'"}.join(", ")+"]"
            else "'#{v.to_s}'"
          end
          "'#{k}'=>#{v}"
        end.sort.join(", ")
        str << '}'
      end

      def self.pp_headers_string(headers)
        headers = WebMock::Util::Headers.normalize_headers(headers)
        seperator = "\n\t "
        str = "{#{seperator} ".dup
        str << headers.map do |k,v|
          v = case v
            when Regexp then v.inspect
            when Array then "["+v.map{|w| "'#{w.to_s}'"}.join(", ")+"]"
            else "'#{v.to_s}'"
          end
          "'#{k}'=>#{v}"
        end.sort.join(",#{seperator} ")
        str << "\n    }"
      end

      def self.decode_userinfo_from_header(header)
        header.sub(/^Basic /, "").unpack("m").first
      end

      def self.basic_auth_header(*credentials)
        "Basic #{Base64.strict_encode64(credentials.join(':')).chomp}"
      end

    end

  end

end
