# frozen_string_literal: true

require "hashdiff"

module WebMock
  class RequestBodyDiff

    def initialize(request_signature, request_stub)
      @request_signature = request_signature
      @request_stub      = request_stub
    end

    def body_diff
      return {} unless request_signature_diffable? && request_stub_diffable?

      Hashdiff.diff(request_signature_body_hash, request_stub_body_hash) do |_path, actual, expected|
        # A regexp that matches the request's value is not a difference.
        # Anything else, including matchers and lambdas, which building a
        # message must not run, is left to Hashdiff by returning nil.
        begin
          true if expected.is_a?(Regexp) && actual.is_a?(String) && expected.match?(actual)
        rescue EncodingError
          # A regexp and a value in incompatible encodings don't match.
          nil
        end
      end
    end

    attr_reader :request_signature, :request_stub
    private :request_signature, :request_stub

    private

    def request_signature_diffable?
      request_signature.json_headers? && request_signature_parseable_json?
    end

    def request_stub_diffable?
      request_stub_body.is_a?(Hash) || request_stub_parseable_json?
    end

    # Bodies are read as WebMock reads them for matching.
    def request_signature_body_hash
      WebMock::Util::Parsers::JSON.parse(request_signature.body)
    end

    def request_stub_body_hash
      return request_stub_body if request_stub_body.is_a?(Hash)

      WebMock::Util::Parsers::JSON.parse(request_stub_body)
    end

    def request_stub_body
      request_stub.request_pattern &&
        request_stub.request_pattern.body_pattern &&
        request_stub.request_pattern.body_pattern.pattern
    end

    def request_signature_parseable_json?
      parseable_json?(request_signature.body)
    end

    def request_stub_parseable_json?
      parseable_json?(request_stub_body)
    end

    def parseable_json?(body_pattern)
      return false unless body_pattern.is_a?(String)

      WebMock::Util::Parsers::JSON.parse(body_pattern)
      true
    rescue WebMock::Util::Parsers::ParseError
      false
    end
  end
end
