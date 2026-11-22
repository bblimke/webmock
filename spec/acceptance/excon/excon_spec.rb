require 'spec_helper'
require 'acceptance/webmock_shared'
require 'acceptance/excon/excon_spec_helper'

describe "Excon" do
  include ExconSpecHelper
  include_context "with WebMock", :no_url_auth

  it 'joins Set-Cookie values into one header and lists each in :cookies, as Excon does' do
    cookies = ["z=1; Expires=Wed, 21 Oct 2026 07:28:00 GMT", "a=2"]
    stub_request(:get, "www.example.com").to_return(headers: {"Set-Cookie" => cookies})
    response = Excon.get("http://www.example.com")
    expect(response.headers["Set-Cookie"]).to eq(cookies.join(", "))
    expect(response[:cookies]).to eq(cookies)
  end

  it "keeps the cookies of a stub when a response's cookies are changed" do
    cookies = ["z=1", "a=2"]
    stub_request(:get, "www.example.com").to_return(headers: {"Set-Cookie" => cookies})
    Excon.get("http://www.example.com")[:cookies].shift
    response = Excon.get("http://www.example.com")
    expect([response.headers["Set-Cookie"], response[:cookies]]).to eq(["z=1, a=2", cookies])
  end

  it "joins cookies in incompatible encodings as bytes" do
    cookies = ["a=caf\u00E9", "b=\xFF".b]
    stub_request(:get, "www.example.com").to_return(headers: {"Set-Cookie" => cookies})
    response = Excon.get("http://www.example.com")
    expect(response.headers["Set-Cookie"]).to eq("a=caf\xC3\xA9, b=\xFF".b)
    expect(response[:cookies]).to eq(cookies)
  end

  describe 'a real response with several cookies' do
    include LocalHTTPServer

    after { WebMock.reset_callbacks }

    it 'gives callbacks each cookie, as Excon lists them' do
      recorded = nil
      WebMock.after_request { |_request, response| recorded = response.headers["Set-Cookie"] }
      raw = "HTTP/1.1 200 OK\r\nSet-Cookie: z=1; Expires=Wed, 21 Oct 2026 07:28:00 GMT\r\nSet-Cookie: a=2\r\n" \
        "Content-Length: 0\r\nConnection: close\r\n\r\n"
      capture_requests(response: raw) { |port| Excon.get("http://127.0.0.1:#{port}/") }
      expect(recorded).to eq(["z=1; Expires=Wed, 21 Oct 2026 07:28:00 GMT", "a=2"])
    end

    it "doesn't let a callback change the cookies the application gets" do
      WebMock.after_request { |_request, response| response.headers["Set-Cookie"].each { |cookie| cookie.replace("redacted") } }
      raw = "HTTP/1.1 200 OK\r\nSet-Cookie: z=1\r\nSet-Cookie: a=2\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
      response = nil
      capture_requests(response: raw) { |port| response = Excon.get("http://127.0.0.1:#{port}/") }
      expect(response[:cookies]).to eq(["z=1", "a=2"])
    end
  end

  it 'lists a single Set-Cookie value in :cookies' do
    stub_request(:get, "www.example.com").to_return(headers: {"Set-Cookie" => "a=1"})
    response = Excon.get("http://www.example.com")
    expect([response.headers["Set-Cookie"], response[:cookies]]).to eq(["a=1", ["a=1"]])
  end

  it 'should allow Excon requests to use query hash paramters' do
    stub_request(:get, "http://example.com/resource/?a=1&b=2").to_return(body: "abc")
    expect(Excon.new('http://example.com').get(path: "resource/", query: {a: 1, b: 2}).body).to eq("abc")
  end

  it 'should support Excon :expects options' do
    stub_request(:get, "http://example.com/").to_return(body: 'a')
    expect { Excon.new('http://example.com').get(expects: 204) }.to raise_error(Excon::Errors::OK)
  end

  context "with response_block" do
    it "should support excon response_block for real requests", net_connect: true do
      a = []
      WebMock.allow_net_connect!
      r = Excon.new("#{HTTP_STATUS_SERVICE}/200", headers: { "Accept" => "*" }).
        get(response_block: lambda {|e, remaining, total| a << e}, chunk_size: 1)
      expect(a).to eq(["2", "0", "0", " ", "O", "K"])
      expect(r.body).to eq("")
    end

    it "should support excon response_block" do
      a = []
      stub_request(:get, "http://example.com/").to_return(body: "abc")
      r = Excon.new('http://example.com').get(response_block: lambda {|e, remaining, total| a << e}, chunk_size: 1)
      expect(a).to eq(['a', 'b', 'c'])
      expect(r.body).to eq("")
    end

    it "should invoke callbacks with response body even if a real request is made", net_connect: true do
      a = []
      WebMock.allow_net_connect!
      response = nil
      WebMock.after_request { |_, res|
        response = res
      }
      r = Excon.new("#{HTTP_STATUS_SERVICE}/200", headers: { "Accept" => "*" }).
        get(response_block: lambda {|e, remaining, total| a << e}, chunk_size: 1)
      expect(response.body).to eq("200 OK")
      expect(a).to eq(["2", "0", "0", " ", "O", "K"])
      expect(r.body).to eq("")
    end
  end

  let(:file) { File.new(__FILE__) }
  let(:file_contents) { File.read(__FILE__) }

  it 'keeps absent and empty request bodies distinct in the history' do
    url = "http://example.com/upload"
    stub_request(:post, url)
    [nil, "", nil].each { |body| Excon.post(url, body: body) }
    expect(executed_requests.map(&:body)).to eq([nil, "", nil])
  end

  it 'handles file uploads correctly' do
    stub_request(:put, "http://example.com/upload").with(body: file_contents)

    yielded_request_body = nil
    WebMock.after_request do |req, res|
      yielded_request_body = req.body
    end

    Excon.new("http://example.com").put(path: "upload", body: file)

    expect(yielded_request_body).to eq(file_contents)
  end

  describe '.request_params_from' do

    it 'rejects invalid request keys' do
      request_params = WebMock::HttpLibAdapters::ExconAdapter.request_params_from(body: :keep, fake: :reject)
      expect(request_params).to eq(body: :keep)
    end

  end

end
