require "spec_helper"

RSpec.describe WebMock::TrailingSlashHint do
  def difference(pattern, url, method: :get)
    described_class.difference(pattern, WebMock::RequestSignature.new(method, url))
  end

  it "notices a slash the request URL has and the stub's doesn't" do
    expect(difference(WebMock::RequestPattern.new(:get, "www.example.com/users"), "http://www.example.com/users/")).to eq(:added)
  end

  it "notices a slash the stub's URL has and the request URL doesn't, with a query" do
    pattern = WebMock::RequestPattern.new(:get, "www.example.com/users/").with(query: {"a" => "1"})
    expect(difference(pattern, "http://www.example.com/users?a=1")).to eq(:removed)
  end

  it "gives no hint when the request differs in more than the slash" do
    pattern = WebMock::RequestPattern.new(:get, "www.example.com/users")
    expect(difference(pattern, "http://www.example.com/other/")).to be_nil
    expect(difference(pattern, "http://www.example.com/users/", method: :post)).to be_nil
  end

  it "gives no hint for a URI pattern that isn't a string" do
    expect(difference(WebMock::RequestPattern.new(:get, %r{/users\z}), "http://www.example.com/users/")).to be_nil
  end

  it "compares only the method and the URL, so code given to with doesn't run" do
    patterns = [
      WebMock::RequestPattern.new(:get, "www.example.com/users").with { |_request| raise "ran" },
      WebMock::RequestPattern.new(:get, "www.example.com/users").with(body: ->(_body) { raise "ran" }),
      WebMock::RequestPattern.new(:get, "www.example.com/users").with(body: {"id" => ->(_id) { raise "ran" }}),
      WebMock::RequestPattern.new(:get, "www.example.com/users").with(query: hash_including("id" => ->(_id) { raise "ran" }))
    ]
    patterns.each do |pattern|
      expect(difference(pattern, "http://www.example.com/users/")).to eq(:added)
    end
  end

  it "doesn't raise for a multipart request to a stub with a body" do
    pattern = WebMock::RequestPattern.new(:post, "www.example.com/upload").with(body: "x")
    signature = WebMock::RequestSignature.new(:post, "http://www.example.com/upload/",
      body: "--b\r\n", headers: {"Content-Type" => "multipart/form-data; boundary=b"})
    expect(described_class.difference(pattern, signature)).to eq(:added)
  end

  it "gives no hint for the root path" do
    expect(difference(WebMock::RequestPattern.new(:get, "www.example.com/users"), "http://www.example.com/")).to be_nil
  end
end
