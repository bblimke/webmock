# frozen_string_literal: true

module WebMock
  module Util
    # Failure messages join request bodies of any encoding, which raised
    # Encoding::CompatibilityError for a UTF-8 body next to a binary one.
    # Each part is converted to UTF-8 for display only: bytes that aren't
    # valid UTF-8 are shown escaped, as in "\xFF", and the requests and
    # their signatures keep their own encoding.
    module MessageString
      def self.utf8(value)
        string = value.to_s
        return string if string.ascii_only? || (string.encoding == Encoding::UTF_8 && string.valid_encoding?)

        if string.encoding == Encoding::BINARY || string.encoding == Encoding::UTF_8
          string.dup.force_encoding(Encoding::UTF_8).scrub { |bytes| escape(bytes) }
        else
          string.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
        end
      end

      def self.escape(bytes)
        bytes.unpack("C*").map { |byte| format("\\x%02X", byte) }.join
      end
      private_class_method :escape
    end
  end
end
