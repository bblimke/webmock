require "hashdiff"
require "JSON"

module WebMock
 class RequestBodyDiff

  def initialize(request_signature, request_stub)
    @request_signature = request_signature
    @request_stub = request_stub
    @body_pattern = nil
    @body_pattern_hash = nil
  end

  def body_diff
    request_pattern = @request_stub.request_pattern
    return {} unless request_pattern
    @body_pattern = request_pattern.body_pattern
    return {} unless @body_pattern
    return {} unless body_pattern_diffable?
    @body_pattern_hash = @body_pattern.pattern
    HashDiff.diff(request_signature_body_hash, stub_body_hash)
  end

  private

  def body_pattern_diffable?
    @body_pattern.pattern.is_a?(Hash) || body_pattern_parseable_as_json?
  end

  def body_pattern_parseable_as_json?
    return false unless @body_pattern.pattern.is_a?(String)
    begin
      JSON.parse(@body_pattern.pattern)
      true
    rescue JSON::ParserError
      false
    end
  end

  def stub_body_hash
    case @body_pattern_hash
      when Hash
        @body_pattern_hash
      when String
        JSON.parse(@body_pattern_hash)
      else
        raise "Don't know how to handle body pattern #{@body_pattern_hash.inspect}"
    end
  end

  def request_signature_body_hash
    case @request_signature.headers["Content-Type"]
      when "application/json"
        JSON.parse(@request_signature.body)
      else
        {}
    end
  end
 end
end
