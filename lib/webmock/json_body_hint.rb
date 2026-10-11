# frozen_string_literal: true

require "json"

module WebMock
  # A body declared as a string must match the request body exactly, which for
  # JSON includes key order and whitespace. When a request fails to match only
  # because of that, failure messages suggest declaring the body as a hash.
  # See #485.
  module JsonBodyHint
    ADVICE = "A body declared as a string must match exactly. To match it as JSON, " \
             "declare it as a hash, for example with(body: JSON.parse(json_string))."

    STUB_HINT = "Hint: the request body is the same JSON as the body of this stub, " \
                "but formatted differently, for example with keys in another order. #{ADVICE}"

    EXPECTATION_HINT = "Hint: a request was made with the same JSON body as expected, " \
                       "but formatted differently, for example with keys in another order. #{ADVICE}"

    # True when the pattern declares its body as a JSON object or array string,
    # the request has a JSON content type and a body that parses to the same
    # JSON but is written differently, and the pattern's method, URI and headers
    # match the request. A block given to the pattern is not called.
    def self.applies?(request_pattern, request_signature)
      return false unless request_pattern.is_a?(RequestPattern) && request_pattern.body_pattern

      expected = request_pattern.body_pattern.pattern
      actual = request_signature.body
      return false unless expected.is_a?(String) && actual.is_a?(String) && expected != actual
      return false unless request_signature.json_headers?

      expected_json = parse_json(expected)
      return false unless expected_json.is_a?(Hash) || expected_json.is_a?(Array)
      # eql? compares nested values strictly, so 1 and 1.0 are different.
      return false unless expected_json.eql?(parse_json(actual))

      matches_except_body?(request_pattern, request_signature)
    end

    def self.matches_except_body?(request_pattern, request_signature)
      request_pattern.method_pattern.matches?(request_signature.method) &&
        request_pattern.uri_pattern.matches?(request_signature.uri) &&
        (request_pattern.headers_pattern.nil? || request_pattern.headers_pattern.matches?(request_signature.headers))
    end

    def self.parse_json(string)
      ::JSON.parse(string)
    rescue ::JSON::JSONError, EncodingError
      nil
    end
    private_class_method :matches_except_body?, :parse_json
  end
end
