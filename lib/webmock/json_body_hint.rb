# frozen_string_literal: true

require "json"

module WebMock
  # Hints in failure messages about JSON request bodies.
  #
  # A body declared as a string must match the request body exactly, which for
  # JSON includes key order and whitespace. When a request fails to match only
  # because of that, failure messages suggest declaring the body as a hash.
  # See #485.
  #
  # A body declared as a hash, an array, hash_including or hash_excluding is
  # matched against the body as JSON.parse reads it, unless it matches any
  # body, as {} does, while WebMock 3.x also read some invalid JSON, such as
  # {a: 1}. When a request fails to match only because its body isn't valid
  # JSON, failure messages say so.
  #
  # A hint is extra, so an error while working one out, for example from a
  # header pattern, means no hint rather than a broken failure message.
  module JsonBodyHint
    ADVICE = "A body declared as a string must match exactly. To match it as JSON, " \
             "declare it as a hash, for example with(body: JSON.parse(json_string))."

    STUB_HINT = "Hint: the request body is the same JSON as the body of this stub, " \
                "but formatted differently, for example with keys in another order. #{ADVICE}"

    EXPECTATION_HINT = "Hint: a request was made with the same JSON body as expected, " \
                       "but formatted differently, for example with keys in another order. #{ADVICE}"

    INVALID_JSON_ADVICE = "WebMock 4.0 and later read JSON request bodies only with JSON.parse, " \
                          "while earlier versions also matched some bodies that aren't valid JSON, such as {a: 1}."

    BYTE_ORDER_MARK = [0xEF, 0xBB, 0xBF].pack("C*").freeze
    private_constant :BYTE_ORDER_MARK

    # %s is the parser's error.
    INVALID_JSON_HINTS = {
      stub: "Hint: the request body isn't valid JSON (%s), so a stub above with a body declared as " \
            "a hash, an array, hash_including or hash_excluding can't match it. #{INVALID_JSON_ADVICE}",
      expectation: "Hint: a request was made with a body that isn't valid JSON (%s), " \
                   "so it can't match the expected body. #{INVALID_JSON_ADVICE}"
    }.freeze

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
      patterns, body_pattern = body_pattern_of(request_pattern)
      return false unless body_pattern && body_differs_only_in_formatting?(body_pattern, request_signature)

      patterns.all? { |pattern| matches_except_body?(pattern, request_signature) }
    rescue StandardError
      false
    end

    # The hint for an expected request that didn't match: that the JSON is
    # formatted differently, or that the body isn't valid JSON. At most one of
    # them fits, since one needs a body declared as a string and the other a
    # hash, an array, hash_including or hash_excluding.
    def self.expectation_hint(request_pattern, request_signature)
      return EXPECTATION_HINT if applies?(request_pattern, request_signature)

      invalid_json_hint([request_pattern], request_signature, :expectation)
    end

    # The hint, for kind :stub or :expectation, when the request body isn't
    # valid JSON and that is the only reason one of the patterns doesn't
    # match: it declares its body as a hash, an array, hash_including or
    # hash_excluding, which doesn't match a body that doesn't parse, and the
    # method, URI and headers of all of its parts match the request. The
    # body is parsed at most once, and only when a pattern could get the hint.
    def self.invalid_json_hint(request_patterns, request_signature, kind)
      candidates = request_patterns.filter_map { |request_pattern| body_pattern_of(request_pattern) }
      # Method patterns run no user code, so they can rule out patterns
      # before the body is parsed.
      candidates.select! do |patterns, body_pattern|
        body_pattern.parses_body? && patterns.all? { |pattern| pattern.method_pattern.matches?(request_signature.method) }
      end
      return if candidates.empty? || !request_signature.json_headers?

      # The body that a hash or array pattern reads, as in BodyPattern#matches?.
      error = parse_error(request_signature.serialized_body || request_signature.body)
      return unless error && candidates.any? { |patterns, body_pattern| fails_only_on_body?(patterns, body_pattern, request_signature) }

      format(INVALID_JSON_HINTS.fetch(kind), short_error(error))
    rescue StandardError
      nil
    end

    # A pattern made of parts that must all match, such as an RSpec expectation
    # with conditions, responds to #patterns. A stub stands for its pattern.
    def self.parts_of(request_pattern)
      parts = request_pattern.respond_to?(:patterns) ? request_pattern.patterns : [request_pattern]
      parts.map { |part| part.is_a?(RequestStub) ? part.request_pattern : part }
    end

    # The parts of the pattern and the body pattern of the only part that
    # declares a body, or nil when none or several do, or when a part has a
    # block given to with.
    def self.body_pattern_of(request_pattern)
      patterns = parts_of(request_pattern)
      return unless patterns.all? { |pattern| pattern.is_a?(RequestPattern) && pattern.with_block.nil? }

      with_body = patterns.select(&:body_pattern)
      [patterns, with_body.first.body_pattern] if with_body.size == 1
    end

    def self.body_differs_only_in_formatting?(body_pattern, request_signature)
      expected = body_pattern.pattern
      actual = request_signature.body
      return false unless expected.is_a?(String) && actual.is_a?(String) && expected != actual
      return false unless request_signature.json_headers?

      # The advice is to declare the body as JSON.parse(json_string), so
      # the stub's string must parse with JSON.parse itself. The request
      # body is read as WebMock reads it for matching.
      expected_json = parse_json { ::JSON.parse(expected) }
      return false unless expected_json.is_a?(Hash) || expected_json.is_a?(Array)

      # eql? compares nested values strictly, so 1 and 1.0 are different.
      expected_json.eql?(parse_json { WebMock::Util::Parsers::JSON.parse(actual) })
    end

    # A body that doesn't parse reaches the body pattern as no body, so it is
    # given none here: the body isn't parsed again, and no user code runs, as
    # the pattern has nothing to compare its values with. Some patterns, such
    # as hash_including({}), match any body, so they get no hint. A pattern
    # that raises, for example a header regexp in an encoding that doesn't
    # fit the request header, gets no hint, while the others still can.
    def self.fails_only_on_body?(patterns, body_pattern, request_signature)
      !body_pattern.matches?(nil, request_signature.content_type) &&
        patterns.all? { |pattern| matches_except_body?(pattern, request_signature) }
    rescue StandardError
      false
    end

    # The parser's error, or nil when the body parses, is blank after a byte
    # order mark, which the parser drops, or is nested deeper than WebMock
    # reads. None of those is what the hint is about.
    def self.parse_error(body)
      return unless body.is_a?(String) && !body.b.delete_prefix(BYTE_ORDER_MARK).match?(/\A[ \t\r\n]*\z/)

      WebMock::Util::Parsers::JSON.parse(body)
      nil
    rescue WebMock::Util::Parsers::ParseError => error
      error.message unless error.cause.is_a?(::JSON::NestingError)
    end

    # Older json versions quote the rest of the body, json 2.5 starts with a
    # line of its C source, such as "809: ", and json 2.8 and 2.9 cut the
    # quote at 32 bytes, which can leave part of a character at the end.
    def self.short_error(message)
      message = message.delete_prefix(WebMock::Util::Parsers::JSON::ERROR_PREFIX)
      cut = message.length > 1000
      message = WebMock::Util::MessageString.utf8(message[0, 1000].scrub("")).gsub(/\s+/, " ").sub(/\A\d+: /, "").strip
      cut || message.length > 100 ? "#{message[0, 100]}..." : message
    end

    def self.matches_except_body?(request_pattern, request_signature)
      request_pattern.method_pattern.matches?(request_signature.method) &&
        request_pattern.uri_pattern.matches?(request_signature.uri) &&
        (request_pattern.headers_pattern.nil? || request_pattern.headers_pattern.matches?(request_signature.headers))
    end

    def self.parse_json
      yield
    rescue ::JSON::JSONError, EncodingError, WebMock::Util::Parsers::ParseError
      nil
    end
    private_class_method :parts_of, :body_pattern_of, :body_differs_only_in_formatting?, :fails_only_on_body?,
                         :parse_error, :short_error, :matches_except_body?, :parse_json
  end
end
