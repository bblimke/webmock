require 'spec_helper'
require 'ostruct'
require 'acceptance/webmock_shared'
require 'acceptance/net_http/net_http_spec_helper'
require 'acceptance/net_http/net_http_shared'

include NetHTTPSpecHelper

describe "Net:HTTP" do
  include_examples "with WebMock", :no_url_auth

  let(:port) { WebMockServer.instance.port }

  describe "marshalling" do
    class TestMarshalingInWebMockNetHTTP
      attr_accessor :r
    end
    before(:each) do
      @b = TestMarshalingInWebMockNetHTTP.new
    end
    after(:each) do
      WebMock.enable!
    end
    it "should be possible to load object marshalled when webmock was disabled" do
      WebMock.disable!
      original_constants = [
        Net::HTTP::Get,
        Net::HTTP::Post,
        Net::HTTP::Put,
        Net::HTTP::Delete,
        Net::HTTP::Head,
        Net::HTTP::Options
      ]
      @b.r = original_constants
      original_serialized = Marshal.dump(@b)
      Marshal.load(original_serialized)
      WebMock.enable!
      Marshal.load(original_serialized)
    end

    it "should be possible to load object marshalled when webmock was enabled"  do
      WebMock.enable!
      new_constants = [
        Net::HTTP::Get,
        Net::HTTP::Post,
        Net::HTTP::Put,
        Net::HTTP::Delete,
        Net::HTTP::Head,
        Net::HTTP::Options
      ]
      @b.r = new_constants
      new_serialized = Marshal.dump(@b)
      Marshal.load(new_serialized)
      WebMock.disable!
      Marshal.load(new_serialized)
    end
  end

  describe "constants" do
    it "should still have const Get defined on replaced Net::HTTP" do
      expect(Object.const_get("Net").const_get("HTTP").const_defined?("Get")).to be_truthy
    end

    it "should still have const Get within constants on replaced Net::HTTP" do
      expect(Object.const_get("Net").const_get("HTTP").constants.map(&:to_s)).to include("Get")
    end

    it "should still have const Get within constants on replaced Net::HTTP" do
      expect(Object.const_get("Net").const_get("HTTP").const_get("Get")).not_to be_nil
    end

    if Module.method(:const_defined?).arity != 1
      it "should still have const Get defined (and not inherited) on replaced Net::HTTP" do
        expect(Object.const_get("Net").const_get("HTTP").const_defined?("Get", false)).to be_truthy
      end
    end

    if Module.method(:const_get).arity != 1
      it "should still be able to get non inherited constant Get on replaced Net::HTTP" do
        expect(Object.const_get("Net").const_get("HTTP").const_get("Get", false)).not_to be_nil
      end
    end

    if Module.method(:constants).arity != 0
      it "should still Get within non inherited constants on replaced Net::HTTP" do
        expect(Object.const_get("Net").const_get("HTTP").constants(false).map(&:to_s)).to include("Get")
      end
    end

    describe "after WebMock is disabled" do
      after(:each) do
        WebMock.enable!
      end
      it "Net::HTTP should have the same constants" do
        orig_consts_number = WebMock::HttpLibAdapters::NetHttpAdapter::OriginalNetHTTP.constants.size
        Net::HTTP.send(:const_set, "TEST_CONST", 10)
        expect(Net::HTTP.constants.size).to eq(orig_consts_number + 1)
        WebMock.disable!
        expect(Net::HTTP.constants.size).to eq(orig_consts_number + 1)
      end
    end
  end

  it "should work with block provided" do
    stub_http_request(:get, "www.example.com").to_return(body: "abc"*100000)
    expect(Net::HTTP.start("www.example.com") { |query| query.get("/") }.body).to eq("abc"*100000)
  end

  it "should handle requests with raw binary data" do
    body = "\x14\x00\x00\x00\x70\x69\x6e\x67\x00\x00"
    stub_http_request(:post, "www.example.com").with(body: body).to_return(body: "abc")
    req = Net::HTTP::Post.new("/")
    req.body = body
    req.content_type = "application/octet-stream"
    expect(Net::HTTP.start("www.example.com") { |http| http.request(req)}.body).to eq("abc")
  end

  it "raises an ArgumentError if passed headers as symbols if RUBY_VERSION < 2.3.0" do
    uri = URI.parse("http://google.com/")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)

    # Net::HTTP calls downcase on header keys assigned with []=
    # In Ruby 1.8.7 symbols do not respond to downcase
    #
    # Meaning you can not assign header keys as symbols in ruby 1.8.7 using []=
    if :symbol.respond_to?(:downcase)
      request[:InvalidHeaderSinceItsASymbol] = "this will not be valid"
    else
      request.instance_eval do
        @header = request.to_hash.merge({InvalidHeaderSinceItsASymbol: "this will not be valid"})
      end
    end

    if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new('2.3.0')
      expect do
        http.request(request)
      end.to raise_error ArgumentError, "Net:HTTP does not accept headers as symbols"
    else
      stub_http_request(:get, "google.com").with(headers: { InvalidHeaderSinceItsASymbol: "this will not be valid" })
      expect do
        http.request(request)
      end.not_to raise_error
    end
  end

  it "should handle multiple values for the same response header" do
    stub_http_request(:get, "www.example.com").to_return(headers: { 'Set-Cookie' => ['foo=bar', 'bar=bazz'] })
    response = Net::HTTP.get_response(URI.parse("http://www.example.com/"))
    expect(response.get_fields('Set-Cookie')).to eq(['bar=bazz', 'foo=bar'])
  end

  it "should yield block on response" do
    stub_http_request(:get, "www.example.com").to_return(body: "abc")
    response_body = ""
    http_request(:get, "http://www.example.com/") do |response|
      response_body = response.body
    end
    expect(response_body).to eq("abc")
  end

  it "should handle Net::HTTP::Post#body" do
    stub_http_request(:post, "www.example.com").with(body: "my_params").to_return(body: "abc")
    req = Net::HTTP::Post.new("/")
    req.body = "my_params"
    expect(Net::HTTP.start("www.example.com") { |http| http.request(req)}.body).to eq("abc")
  end

  it "should handle Net::HTTP::Post#body_stream" do
    stub_http_request(:post, "www.example.com").with(body: "my_params").to_return(body: "abc")
    req = Net::HTTP::Post.new("/")
    req.body_stream = StringIO.new("my_params")
    expect(Net::HTTP.start("www.example.com") { |http| http.request(req)}.body).to eq("abc")
  end

  it "should behave like Net::HTTP and raise error if both request body and body argument are set" do
    stub_http_request(:post, "www.example.com").with(body: "my_params").to_return(body: "abc")
    req = Net::HTTP::Post.new("/")
    req.body = "my_params"
    expect {
      Net::HTTP.start("www.example.com") { |http| http.request(req, "my_params")}
    }.to raise_error("both of body argument and HTTPRequest#body set")
  end

  it "should return a Net::ReadAdapter from response.body when a stubbed request is made with a block and #read_body" do
    WebMock.stub_request(:get, 'http://example.com/').to_return(body: "the body")
    response = Net::HTTP.new('example.com', 80).request_get('/') { |r| r.read_body { } }
    expect(response.body).to be_a(Net::ReadAdapter)
  end

  it "should have request 1 time executed in registry after 1 real request", net_connect: true do
    WebMock.allow_net_connect!
    http = Net::HTTP.new('localhost', port)
    http.get('/') {}
    expect(WebMock::RequestRegistry.instance.requested_signatures.hash.size).to eq(1)
    expect(WebMock::RequestRegistry.instance.requested_signatures.hash.values.first).to eq(1)
  end

  it "should work with Addressable::URI passed to Net::HTTP.get_response" do
    stub_request(:get, 'http://www.example.com/hello?a=1').to_return(body: "abc")
    expect(Net::HTTP.get_response(Addressable::URI.parse('http://www.example.com/hello?a=1')).body).to eq("abc")
  end

  describe "connecting on Net::HTTP.start" do
    before(:each) do
      @http = Net::HTTP.new('www.google.com', 443)
      @http.use_ssl = true
      @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    describe "when net http is allowed" do
      it "should not connect to the server until the request", net_connect: true do
        WebMock.allow_net_connect!
        @http.start {|conn|
          expect(conn.peer_cert).to be_nil
        }
      end

      it "should connect to the server on start", net_connect: true do
        WebMock.allow_net_connect!(net_http_connect_on_start: true)
        @http.start {|conn|
          cert = OpenSSL::X509::Certificate.new conn.peer_cert
          expect(cert).to be_a(OpenSSL::X509::Certificate)
        }
      end

    end

    describe "when net http is disabled and allowed only for some hosts" do
      it "should not connect to the server until the request", net_connect: true do
        WebMock.disable_net_connect!(allow: "www.google.com")
        @http.start {|conn|
          expect(conn.peer_cert).to be_nil
        }
      end

      it "should connect to the server on start", net_connect: true do
        WebMock.disable_net_connect!(allow: "www.google.com", net_http_connect_on_start: true)
        @http.start {|conn|
          cert = OpenSSL::X509::Certificate.new conn.peer_cert
          expect(cert).to be_a(OpenSSL::X509::Certificate)
        }
      end

      it "should connect to the server if the URI matches an regex", net_connect: true do
        WebMock.disable_net_connect!(allow: /google.com/)
        Net::HTTP.get('www.google.com','/')
      end

      it "should connect to the server if the URI matches any regex the array", net_connect: true do
        WebMock.disable_net_connect!(allow: [/google.com/, /yahoo.com/])
        Net::HTTP.get('www.google.com','/')
      end

    end

  end

  describe "when net_http_connect_on_start is true" do
    before(:each) do
      WebMock.allow_net_connect!(net_http_connect_on_start: true)
    end
    it_should_behave_like "Net::HTTP"
  end

  describe "when net_http_connect_on_start is false" do
    before(:each) do
      WebMock.allow_net_connect!(net_http_connect_on_start: false)
    end
    it_should_behave_like "Net::HTTP"
  end

  describe 'after_request callback support', net_connect: true do
    let(:expected_body_regex) { /hello world/ }

    before(:each) do
      WebMock.allow_net_connect!
      @callback_invocation_count = 0
      WebMock.after_request do |_, response|
        @callback_invocation_count += 1
        @callback_response = response
      end
    end

    after(:each) do
      WebMock.reset_callbacks
    end

    def perform_get_with_returning_block
      http_request(:get, "http://localhost:#{port}/") do |response|
        return response.body
      end
    end

    it "should support the after_request callback on an request with block and read_body" do
      response_body = ''.dup
      http_request(:get, "http://localhost:#{port}/") do |response|
        response.read_body { |fragment| response_body << fragment }
      end
      expect(response_body).to match(expected_body_regex)

      expect(@callback_response.body).to eq(response_body)
    end

    it "should support the after_request callback on a request with a returning block" do
      response_body = perform_get_with_returning_block
      expect(response_body).to match(expected_body_regex)
      expect(@callback_response).to be_instance_of(WebMock::Response)
      expect(@callback_response.body).to eq(response_body)
    end

    it "should only invoke the after_request callback once, even for a recursive post request" do
      Net::HTTP.new('localhost', port).post('/', nil)
      expect(@callback_invocation_count).to eq(1)
    end
  end

  it "should match http headers, even if their values have been set in a request as numbers" do
    WebMock.disable_net_connect!

    stub_request(:post, "www.example.com").with(headers: {"My-Header" => 99})

    uri = URI.parse('http://www.example.com/')
    req = Net::HTTP::Post.new(uri.path)
    req['My-Header'] = 99

    res = Net::HTTP.start(uri.host, uri.port) do |http|
      http.request(req, '')
    end
  end
end
