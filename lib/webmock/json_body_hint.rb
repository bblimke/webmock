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

    # True when one of the patterns declares its body as a JSON object or array
    # string, the request has a JSON content type and a body that parses to the
    # same JSON but is written differently, and the method, URI and headers of
    # every pattern match the request. Any other patterns the request has to
    # match, such as the conditions of an RSpec expectation, must not declare
    # a body of their own.
    #
    # Building a failure message must not call a block given to with, which
    # could raise and replace the failure, or repeat side effects. So there is
    # no hint when any of the patterns has one.
    #
    # The body is checked first, since that runs no user code, so URI and
    # header matchers are only evaluated when a hint is otherwise possible.
    def self.applies?(request_pattern, request_signature)
      patterns = parts_of(request_pattern)
      return false unless patterns.all? { |pattern| pattern.is_a?(RequestPattern) && pattern.with_block.nil? }

      with_body = patterns.select(&:body_pattern)
      return false unless with_body.size == 1
      return false unless body_differs_only_in_formatting?(with_body.first.body_pattern, request_signature)

      patterns.all? { |pattern| matches_except_body?(pattern, request_signature) }
    end

    # A pattern made of parts that must all match, such as an RSpec expectation
    # with conditions, responds to #patterns. A stub stands for its pattern.
    def self.parts_of(request_pattern)
      parts = request_pattern.respond_to?(:patterns) ? request_pattern.patterns : [request_pattern]
      parts.map { |part| part.is_a?(RequestStub) ? part.request_pattern : part }
    end

    def self.body_differs_only_in_formatting?(body_pattern, request_signature)
      expected = body_pattern.pattern
      actual = request_signature.body
      return false unless expected.is_a?(String) && actual.is_a?(String) && expected != actual
      return false unless request_signature.json_headers?

      expected_json = parse_json(expected)
      return false unless expected_json.is_a?(Hash) || expected_json.is_a?(Array)

      # eql? compares nested values strictly, so 1 and 1.0 are different.
      expected_json.eql?(parse_json(actual))
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
    private_class_method :parts_of, :body_differs_only_in_formatting?, :matches_except_body?, :parse_json
  end
end
