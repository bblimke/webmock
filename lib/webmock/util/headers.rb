require_relative "headers/normalizer"

module WebMock
  module Util
    class Headers
      def self.normalize_headers(headers)
        return nil unless headers

        array = headers.map { |name, value|
          Normalizer.new(name, value).call
        }

        Hash[*array.inject([]) {|r,x| r + x}]
      end

      def self.sorted_headers_string(headers)
        headers = WebMock::Util::Headers.normalize_headers(headers)
        str = '{'
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

      def self.decode_userinfo_from_header(header)
        header.sub(/^Basic /, "").unpack("m").first
      end
    end
  end
end
