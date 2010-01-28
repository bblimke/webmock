module WebMock

  module Util

    class Headers

      def self.normalize_headers(headers)
        return nil unless headers
        array = headers.map { |name, value|
          [name.to_s.split(/_|-/).map { |segment| segment.capitalize }.join("-"), value.is_a?(Regexp) ? value : value.to_s]
        }
        Hash[*array.flatten]
      end

      def self.decode_userinfo_from_header(header)
        header.sub(/^Basic /, "").unpack("m").first
      end

    end

  end

end
