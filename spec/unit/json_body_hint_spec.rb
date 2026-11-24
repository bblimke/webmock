require 'spec_helper'

describe WebMock::JsonBodyHint do
  let(:content_type) { "application/json" }
  let(:request_body) { '{"b":2,"a":1}' }
  let(:request_signature) do
    WebMock::RequestSignature.new(:post, "www.example.com",
      body: request_body, headers: {"Content-Type" => content_type})
  end

  def pattern(body, uri = "www.example.com")
    WebMock::RequestPattern.new(:post, uri, body: body)
  end

  def applies?(request_pattern)
    WebMock::JsonBodyHint.applies?(request_pattern, request_signature)
  end

  it "applies when the bodies are the same JSON with keys in another order" do
    expect(applies?(pattern('{"a":1,"b":2}'))).to be true
  end

  it "applies when the bodies differ only in whitespace" do
    expect(applies?(pattern('{"b": 2, "a": 1}'))).to be true
  end

  it "applies to nested JSON in a top level array" do
    request_signature.body = '[{"b":2,"a":{"d":4,"c":3}}]'
    expect(applies?(pattern('[{"a":{"c":3,"d":4},"b":2}]'))).to be true
  end

  context "when the request has a +json content type with parameters" do
    let(:content_type) { "application/vnd.api+json; charset=utf-8" }

    it "applies" do
      expect(applies?(pattern('{"a":1,"b":2}'))).to be true
    end
  end

  it "applies when the request body starts with a byte order mark" do
    request_signature.body = "\uFEFF" + request_body
    expect(applies?(pattern('{"a":1,"b":2}'))).to be true
  end

  it "does not apply when the declared body doesn't parse with JSON.parse, which the advice uses" do
    expect(applies?(pattern("\uFEFF{\"a\":1,\"b\":2}"))).to be false
  end

  it "does not apply when the JSON is different" do
    expect(applies?(pattern('{"a":1,"b":3}'))).to be false
  end

  it "does not apply when the bodies are identical" do
    expect(applies?(pattern(request_body))).to be false
  end

  it "does not apply when the body is declared as a hash" do
    expect(applies?(pattern({"a" => 1, "b" => 3}))).to be false
  end

  it "does not apply when the declared body is not JSON" do
    expect(applies?(pattern("a=1&b=2"))).to be false
  end

  it "does not apply when the declared body is a JSON scalar" do
    request_signature.body = '"text"'
    expect(applies?(pattern(' "text" '))).to be false
  end

  it "does not apply when the request has no body" do
    request_signature.body = nil
    expect(applies?(pattern('{"a":1,"b":2}'))).to be false
  end

  it "does not apply when the pattern would not match the request for another reason" do
    expect(applies?(pattern('{"a":1,"b":2}', "www.example.org"))).to be false
  end

  it "does not apply when the pattern has no body" do
    expect(applies?(WebMock::RequestPattern.new(:post, "www.example.com"))).to be false
  end

  it "does not apply when an empty JSON object is declared and the request body has keys" do
    expect(applies?(pattern('{}'))).to be false
  end

  it "applies when an empty JSON object differs only in whitespace" do
    request_signature.body = '{}'
    expect(applies?(pattern('{ }'))).to be true
  end

  it "does not apply when numbers differ in type, as the body diff shows them as different" do
    request_signature.body = '{"a":1}'
    expect(applies?(pattern('{"a":1.0}'))).to be false
  end

  it "does not raise for a request body that isn't valid JSON, such as YAML aliases" do
    request_signature.body = '[&a 1, *a]'
    expect(applies?(pattern('[1,1]'))).to be false
  end

  it "does not raise for a declared body tagged with an encoding that does not fit its bytes" do
    # json 2.1 on older Rubies reads these bytes as UTF-8; newer versions reject them.
    expect { applies?(pattern('{"a":1,"b":2}'.dup.force_encoding("UTF-16LE"))) }.not_to raise_error
  end

  it "does not check the URI unless the body differs only in formatting" do
    uri_check = ->(_uri) { raise "the URI should not be checked" }
    expect(applies?(WebMock::RequestPattern.new(:post, uri_check))).to be false
    expect(applies?(WebMock::RequestPattern.new(:post, uri_check, body: {"a" => 1, "b" => 2}))).to be false
    expect(applies?(WebMock::RequestPattern.new(:post, uri_check, body: '{"a":1,"b":3}'))).to be false
  end

  it "does not apply, and does not call the block, when the pattern has a block" do
    request_pattern = pattern('{"a":1,"b":2}').with { |_request| raise "the block should not be called" }
    expect(applies?(request_pattern)).to be false
  end

  context "when the request content type is not JSON" do
    let(:content_type) { "text/plain" }

    it "does not apply, since a hash body would not match either" do
      expect(applies?(pattern('{"a":1,"b":2}'))).to be false
    end
  end

  describe "for a request body that isn't valid JSON" do
    let(:request_body) { "{a: 1}" }

    def hint(request_patterns, kind = :stub)
      WebMock::JsonBodyHint.invalid_json_hint(request_patterns, request_signature, kind)
    end

    it "explains why a stub with a hash body can't match it" do
      expect(hint([pattern({a: 1})])).to match(
        /\AHint: the request body isn't valid JSON \(.+\), so a stub above with a body declared as a hash, an array, hash_including or hash_excluding can't match it\. WebMock 4\.0 and later read JSON request bodies only with JSON\.parse, while earlier versions also matched some bodies that aren't valid JSON, such as \{a: 1\}\.\z/
      )
    end

    it "has a version for an expected request" do
      expect(hint([pattern({a: 1})], :expectation)).to match(
        /\AHint: a request was made with a body that isn't valid JSON \(.+\), so it can't match the expected body\. WebMock 4\.0 and later /
      )
      expect(WebMock::JsonBodyHint.expectation_hint(pattern({a: 1}), request_signature)).to eq(hint([pattern({a: 1})], :expectation))
    end

    it "explains it for hash_including and array bodies" do
      expect(hint([pattern(hash_including(a: 1))])).to start_with("Hint: the request body isn't valid JSON")
      request_signature.body = "['a', 1]"
      expect(hint([pattern(["a", 1])])).to start_with("Hint: the request body isn't valid JSON")
    end

    it "gives the hint when an earlier pattern doesn't match for another reason" do
      expect(hint([pattern({a: 1}, "www.example.org"), pattern({a: 1})])).to start_with("Hint:")
    end

    it "quotes the parser's error without WebMock's prefix" do
      error = begin
        JSON.parse(request_body)
      rescue JSON::ParserError => e
        e.message.sub(/\A\d+: /, "").gsub(/\s+/, " ").strip
      end
      expect(hint([pattern({a: 1})])).to include("isn't valid JSON (#{error})")
      expect(hint([pattern({a: 1})])).not_to include(WebMock::Util::Parsers::JSON::ERROR_PREFIX)
    end

    it "gives no hint for a body pattern that matches any body, such as hash_including({})" do
      expect(hint([pattern({})])).to be_nil
      expect(hint([pattern(hash_including({}))])).to be_nil
      expect(hint([pattern(hash_excluding({}))])).to be_nil
    end

    it "shortens the error to one line of valid UTF-8, without a line number from json's source" do
      cut = ("\u00e9" * 30).b[0, 59].force_encoding(Encoding::UTF_8)
      message = "Invalid JSON string: 809: unexpected token at 'ab\ncd #{cut}#{'x' * 300}'"
      allow(WebMock::Util::Parsers::JSON).to receive(:parse).and_raise(WebMock::Util::Parsers::ParseError, message)
      result = hint([pattern({a: 1})])
      error = result[/isn't valid JSON \((.*)\), so a stub/, 1]
      expect(result).to be_valid_encoding
      expect(error).to start_with("unexpected token at 'ab cd ")
      expect(error.length).to eq(103)
      expect(error).to end_with("...")
      expect(error).not_to include("\\x")
    end

    it "works for a body with characters outside ASCII" do
      request_signature.body = "{\"a\": x#{"\u00e9" * 40}}"
      expect(hint([pattern({a: 1})])).to be_valid_encoding
    end

    it "reads the serialized body, as matching does" do
      signature = WebMock::RequestSignature.new(:post, "www.example.com",
        body: StringIO.new("{a: 1}"), serialized_body: "{a: 1}", headers: {"Content-Type" => content_type})
      expect(WebMock::JsonBodyHint.invalid_json_hint([pattern({a: 1})], signature, :stub)).to start_with("Hint:")
    end

    it "gives no hint when the body is valid JSON" do
      request_signature.body = '{"a":2}'
      expect(hint([pattern({a: 1})])).to be_nil
    end

    it "gives no hint for an empty body" do
      request_signature.body = " "
      expect(hint([pattern({a: 1})])).to be_nil
    end

    it "gives no hint for a body that is only a byte order mark" do
      request_signature.body = "\uFEFF"
      expect(hint([pattern({a: 1})])).to be_nil
    end

    it "gives no hint for a pattern whose header pattern raises, rather than raising, but still for others" do
      headers = {"Content-Type" => content_type, "X-Name" => "caf\xC3\xA9".b}
      signature = WebMock::RequestSignature.new(:post, "www.example.com", body: "{a: 1}", headers: headers)
      request_pattern = WebMock::RequestPattern.new(:post, "www.example.com",
        body: {a: 1}, headers: {"X-Name" => /caf\u00e9/})
      expect(WebMock::JsonBodyHint.invalid_json_hint([request_pattern], signature, :stub)).to be_nil
      expect(WebMock::JsonBodyHint.invalid_json_hint([request_pattern, pattern({a: 1})], signature, :stub)).to start_with("Hint:")
      signature.body = '{"b":2,"a":1}'
      request_pattern = WebMock::RequestPattern.new(:post, "www.example.com",
        body: '{"a":1,"b":2}', headers: {"X-Name" => /caf\u00e9/})
      expect(WebMock::JsonBodyHint.applies?(request_pattern, signature)).to be false
    end

    it "gives no hint for valid JSON nested deeper than WebMock reads" do
      depth = WebMock::Util::Parsers::JSON::MAX_NESTING + 1
      request_signature.body = "[" * depth + "]" * depth
      expect(hint([pattern({a: 1})])).to be_nil
    end

    it "gives no hint for a body declared as a string" do
      expect(hint([pattern("{a: 2}")])).to be_nil
    end

    it "gives no hint when the URI doesn't match either" do
      expect(hint([pattern({a: 1}, "www.example.org")])).to be_nil
    end

    it "gives no hint, and does not call the block, when the pattern has a block" do
      request_pattern = pattern({a: 1}).with { |_request| raise "the block should not be called" }
      expect(hint([request_pattern])).to be_nil
    end

    it "does not call a lambda in the body pattern" do
      expect(hint([pattern({a: ->(_value) { raise "the lambda should not be called" }})])).to start_with("Hint:")
    end

    context "when the request content type is not JSON" do
      let(:content_type) { "text/plain" }

      it "gives no hint" do
        expect(hint([pattern({a: 1})])).to be_nil
      end
    end
  end
end
