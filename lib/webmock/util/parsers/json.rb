# frozen_string_literal: true

require "json"
require_relative "parse_error"

module WebMock
  module Util
    module Parsers
      class JSON
        # Deep enough for any real body, and shallow enough for every json
        # gem version to parse in a thread's stack.
        MAX_NESTING = 1000

        # Starts the message of every ParseError raised here.
        ERROR_PREFIX = "Invalid JSON string: "

        def self.parse(json)
          # JSON texts may start with a byte order mark, which parsers may ignore.
          json = to_utf8(json).delete_prefix("\uFEFF")
          ::JSON.parse(json, allow_duplicate_key: true, max_nesting: MAX_NESTING)
        rescue ::JSON::JSONError, EncodingError => e
          raise ParseError, "#{ERROR_PREFIX}#{e.message}"
        end

        # The json gem reads bytes that aren't valid in their encoding, so
        # such a body, for example a binary upload, is rejected here. A
        # binary or US-ASCII string, as read from a socket or from a file in
        # a C locale, is taken as UTF-8.
        def self.to_utf8(json)
          if json.encoding == Encoding::BINARY || json.encoding == Encoding::US_ASCII
            json = json.dup.force_encoding(Encoding::UTF_8)
          end
          raise ParseError, "#{ERROR_PREFIX}it isn't valid #{json.encoding}" unless json.valid_encoding?

          json.encoding == Encoding::UTF_8 ? json : json.encode(Encoding::UTF_8)
        end
        private_class_method :to_utf8
      end
    end
  end
end
