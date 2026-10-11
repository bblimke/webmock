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

  it "does not raise for a request body that YAML would read as aliases" do
    request_signature.body = '[&a 1, *a]'
    expect(applies?(pattern('[1,1]'))).to be false
  end

  it "does not raise for a declared body in an encoding it cannot be read in" do
    expect(applies?(pattern('{"a":1,"b":2}'.dup.force_encoding("UTF-16LE")))).to be false
  end

  it "does not call a block given to the pattern" do
    request_pattern = pattern('{"a":1,"b":2}').with { |_request| raise "the block should not be called" }
    expect(applies?(request_pattern)).to be true
  end

  context "when the request content type is not JSON" do
    let(:content_type) { "text/plain" }

    it "does not apply, since a hash body would not match either" do
      expect(applies?(pattern('{"a":1,"b":2}'))).to be false
    end
  end
end
