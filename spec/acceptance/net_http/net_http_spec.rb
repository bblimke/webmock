require 'spec_helper'
require 'ostruct'
require 'acceptance/webmock_shared'
require 'acceptance/net_http/net_http_spec_helper'
require 'acceptance/net_http/net_http_shared'

include NetHTTPSpecHelper

describe "Net:HTTP" do
  include_examples "with WebMock", :no_url_auth

  let(:port) { WebMockServer.instance.port }

  describe "OPTIONS with an asterisk request target" do
    include LocalHTTPServer

    it "can be stubbed as the path /*" do
      stub_request(:options, "www.example.com/*").to_return(body: "abc")
      response = Net::HTTP.new("www.example.com", 80).request(Net::HTTP::Options.new("*"))
      expect(response.body).to eq("abc")
    end

    it "sends the asterisk form to the server when real requests are allowed" do
      response = nil
      heads = capture_request_heads do |port|
        response = Net::HTTP.start("127.0.0.1", port) { |http| http.request(Net::HTTP::Options.new("*")) }
      end

      expect(response.code).to eq("200")
      expect(heads.first.lines.first).to eq("OPTIONS * HTTP/1.1\r\n")
    end
  end

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

  it "raises an ArgumentError if passed headers as symbols" do
    uri = URI.parse("http://google.com/")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    request[:InvalidHeaderSinceItsASymbol] = "this will not be valid"

    stub_http_request(:get, "google.com").with(headers: { InvalidHeaderSinceItsASymbol: "this will not be valid" })
    expect do
      http.request(request)
    end.not_to raise_error
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

  context "returning response that returns request uri" do
    context "when making a real request" do
      it "should return response that reports request uri" do
        WebMock.allow_net_connect!
        uri = URI.parse("http://localhost:#{port}/")
        response = Net::HTTP.get_response(uri)
        expect(response.uri).to eql(uri)
      end
    end

    it "should return response that returns request uri" do
      stub_request(:get, "www.example.com")
      uri = URI.parse("http://www.example.com/")
      response = Net::HTTP.get_response(uri)
      expect(response.uri).to eql(URI.parse("http://www.example.com/"))
    end
  end

  it "should handle Net::HTTP::Post#body_stream" do
    stub_http_request(:post, "www.example.com").with(body: "my_params").to_return(body: "abc")
    req = Net::HTTP::Post.new("/")
    req.body_stream = StringIO.new("my_params")
    expect(Net::HTTP.start("www.example.com") { |http| http.request(req)}.body).to eq("abc")
  end

  describe "a real response read in the request block" do
    include LocalHTTPServer

    let(:chunks) { ["first,", "second,", "third"] }
    let(:chunked_response) do
      "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n" +
        chunks.map { |chunk| "#{chunk.bytesize.to_s(16)}\r\n#{chunk}\r\n" }.join + "0\r\n\r\n"
    end

    def get(port, headers = {}, &block)
      Net::HTTP.start("127.0.0.1", port) { |http| http.request(Net::HTTP::Get.new("/", headers), &block) }
    end

    after { WebMock.reset_callbacks }

    it "is read whole before the block, so callbacks get all of it" do
      recorded = []
      seen = []
      WebMock.after_request { |_request, response| recorded << response.body }
      capture_requests(4, response: chunked_response) do |port|
        get(port) { |response| response.read_body { |chunk| seen << chunk } }
        get(port) { |response| response.body }
        get(port) { |response| response.read_body(+"before:") }
        get(port) { |_response| break }
      end

      expect(seen).to eq([chunks.join])
      expect(recorded).to eq([chunks.join] * 4)
    end
  end

  describe "a body stream whose read needs a length" do
    include LocalHTTPServer

    # Like a stream that only supports the calls IO.copy_stream makes.
    let(:stream_class) do
      Class.new do
        def initialize(data, at_end = nil)
          @io = StringIO.new(data)
          @at_end = at_end
        end

        def read(length, buffer = nil)
          @io.read(length, buffer) || @at_end
        end
      end
    end

    def upload(http, stream, size)
      req = Net::HTTP::Put.new("/")
      req.body_stream = stream
      req.content_length = size
      http.request(req)
    end

    it "is matched by its content" do
      data = "x" * 40_000
      stub_request(:put, "www.example.com").with(body: data).to_return(body: "ok")
      response = Net::HTTP.start("www.example.com") { |http| upload(http, stream_class.new(data), data.bytesize) }
      expect(response.body).to eq("ok")
    end

    it "is read as before when read is answered by method_missing" do
      # Without respond_to_missing?, so method(:read) raises NameError.
      proxy_class = Class.new do
        def initialize(target)
          @target = target
        end

        def method_missing(name, *args, &block)
          @target.public_send(name, *args, &block)
        end
      end
      stub_request(:put, "www.example.com").with(body: "abc")
      Net::HTTP.start("www.example.com") { |http| upload(http, proxy_class.new(StringIO.new("abc")), 3) }
      expect(WebMock.executed_requests.last.body).to eq("abc")
    end

    it "is read with a buffer when read needs one, as IO.copy_stream reads it" do
      stream = Object.new
      io = StringIO.new("abc")
      stream.define_singleton_method(:read) { |length, buffer| io.read(length, buffer) }
      stub_request(:put, "www.example.com").with(body: "abc")
      Net::HTTP.start("www.example.com") { |http| upload(http, stream, 3) }
      expect(WebMock.executed_requests.last.body).to eq("abc")
    end

    it "is read until it raises EOFError" do
      chunks = ["abc"]
      stream = Object.new
      stream.define_singleton_method(:read) { |_length, _buffer = nil| chunks.shift || raise(EOFError) }
      stub_request(:put, "www.example.com").with(body: "abc")
      Net::HTTP.start("www.example.com") { |http| upload(http, stream, 3) }
      expect(WebMock.executed_requests.last.body).to eq("abc")
    end

    it "joins chunks in incompatible encodings as bytes" do
      chunks = ["é", "\xFF".b]
      stream = Object.new
      stream.define_singleton_method(:read) { |_length, _buffer = nil| chunks.shift }
      stub_request(:put, "www.example.com")
      Net::HTTP.start("www.example.com") { |http| upload(http, stream, 3) }
      expect(WebMock.executed_requests.last.body.b).to eq("\xC3\xA9\xFF".b)
    end

    it "is read until it returns an empty string" do
      stub_request(:put, "www.example.com").with(body: "abc")
      Net::HTTP.start("www.example.com") { |http| upload(http, stream_class.new("abc", ""), 3) }
      expect(WebMock.executed_requests.last.body).to eq("abc")
    end

    it "is sent for real" do
      requests = capture_requests do |port|
        Net::HTTP.start("127.0.0.1", port) { |http| upload(http, stream_class.new("xxxxxxxxxx"), 10) }
      end
      expect(requests.first.last).to eq("xxxxxxxxxx")
    end
  end

  describe "a form set with set_form" do
    include LocalHTTPServer

    def form_request(*form)
      Net::HTTP::Post.new("/form").tap { |req| req.set_form(*form) }
    end

    it "is matched as the URL encoded body Net::HTTP sends" do
      stub_request(:post, "www.example.com/form").with(body: {"foo" => "bar", "baz" => "1 2"})
      response = Net::HTTP.start("www.example.com") do |http|
        http.request(form_request([["foo", "bar"], ["baz", "1 2"]]))
      end

      expect(response.code).to eq("200")
      expect(WebMock.executed_requests.last.body).to eq("foo=bar&baz=1+2")
    end

    it "is recorded without a body when it is multipart, as before" do
      stub_request(:post, "www.example.com/form")
      Net::HTTP.start("www.example.com") do |http|
        http.request(form_request([["foo", "bar"]], "multipart/form-data", boundary: "webmock"))
      end

      expect(WebMock.executed_requests.last.body).to be_nil
    end

    it "is recorded without a body, and sent whole, when given as an enumerator, which may be read only once" do
      requests = capture_requests do |port|
        form = Enumerator.new { |yielder| yielder << ["name", "Alice"] }
        Net::HTTP.start("127.0.0.1", port) { |http| http.request(form_request(form)) }
      end

      expect(requests.first.last).to eq("name=Alice")
      expect(WebMock.executed_requests.last.body).to be_nil
    end

    it "is sent for real as Net::HTTP sends it" do
      forms = lambda do
        [
          [[["foo", "bar"], ["baz", "1 2"]]],
          [[["foo", "bar"], ["file", StringIO.new("abc"), {filename: "a.txt"}]],
            "multipart/form-data", {boundary: "webmock"}]
        ]
      end
      send_forms = lambda do
        capture_requests(2) do |port|
          forms.call.each { |form| Net::HTTP.start("127.0.0.1", port) { |http| http.request(form_request(*form)) } }
        end.map do |head, body|
          [head[/^content-type: .*$/i], head[/^content-length: .*$/i], body]
        end
      end

      with_webmock = send_forms.call
      WebMock.disable!
      without_webmock = begin
        send_forms.call
      ensure
        WebMock.enable!
      end

      expect(with_webmock).to eq(without_webmock)
      expect(with_webmock.first.last).to eq("foo=bar&baz=1+2")
    end

    it "is sent chunked when the request is chunked, as Net::HTTP sends it" do
      send_chunked = lambda do
        capture_requests do |port|
          req = form_request([["foo", "bar"]], "multipart/form-data", boundary: "webmock")
          req["Transfer-Encoding"] = "chunked"
          Net::HTTP.start("127.0.0.1", port) { |http| http.request(req) }
        end.map { |head, body| [head[/^transfer-encoding: .*$/i], body] }
      end

      with_webmock = send_chunked.call
      WebMock.disable!
      without_webmock = begin
        send_chunked.call
      ensure
        WebMock.enable!
      end

      body = "--webmock\r\nContent-Disposition: form-data; name=\"foo\"\r\n\r\nbar\r\n--webmock--\r\n"
      expect(with_webmock).to eq(without_webmock)
      expect(with_webmock.first.last).to eq(body)
    end

    it "encodes its form again when the request is sent again" do
      params = {"some" => "first"}
      req = form_request(params)
      requests = capture_requests(2) do |port|
        Net::HTTP.start("127.0.0.1", port) do |http|
          http.request(req)
          params["some"] = "second"
          http.request(req)
        end
      end

      expect(requests.map(&:last)).to eq(["some=first", "some=second"])
      expect(WebMock.executed_requests.map(&:body)).to eq(["some=first", "some=second"])
    end

    it "keeps matching a stub on its Content-Type when sent again" do
      stub_request(:post, "www.example.com/form").with(headers: {"Content-Type" => "multipart/form-data"})
      req = form_request([["foo", "bar"]], "multipart/form-data")
      codes = Array.new(2) { Net::HTTP.start("www.example.com") { |http| http.request(req) }.code }
      expect(codes).to eq(["200", "200"])
    end
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

  it "should give each stubbed response its own copy of the body" do
    WebMock.stub_request(:get, "http://example.com/").to_return(body: "abc".freeze)
    response = Net::HTTP.get_response(URI("http://example.com/"))
    expect(response.body).not_to be_frozen
    response.body << "!"
    expect(Net::HTTP.get_response(URI("http://example.com/")).body).to eq("abc")
  end

  if Net::HTTP.method_defined?(:response_body_encoding=)
    describe "response body encoding" do
      let(:utf8_body) { "caf\xC3\xA9".b }

      def get_response(response_body_encoding = false, &block)
        http = Net::HTTP.new("www.example.com", 80)
        http.response_body_encoding = response_body_encoding
        http.request(Net::HTTP::Get.new("/"), &block)
      end

      it "should leave the body encoding unchanged by default, like Net::HTTP" do
        stub_request(:get, "www.example.com").to_return(body: utf8_body, headers: {"Content-Type" => "text/plain; charset=utf-8"})
        expect(get_response.body.encoding).to eq(Encoding::BINARY)
      end

      it "should use the charset of the Content-Type header when response_body_encoding is true" do
        stub_request(:get, "www.example.com").to_return(body: utf8_body, headers: {"Content-Type" => "text/plain; charset=utf-8"})
        body = get_response(true).body
        expect(body.encoding).to eq(Encoding::UTF_8)
        expect(body).to eq("café")
      end

      it "should use the charset of a meta tag when response_body_encoding is true" do
        stub_request(:get, "www.example.com").to_return(body: '<html><head><meta charset="Shift_JIS"></head></html>', headers: {"Content-Type" => "text/html"})
        expect(get_response(true).body.encoding).to eq(Encoding::Shift_JIS)
      end

      it "should force the encoding given to response_body_encoding" do
        stub_request(:get, "www.example.com").to_return(body: "caf\xE9".b, headers: {"Content-Type" => "text/plain"})
        body = get_response("ISO-8859-1").body
        expect(body.encoding).to eq(Encoding::ISO_8859_1)
        expect(body.encode(Encoding::UTF_8)).to eq("café")
      end

      it "should use the encoding set with body_encoding= on the response before the body is read" do
        stub_request(:get, "www.example.com").to_return(body: utf8_body)
        body = nil
        get_response do |response|
          response.body_encoding = "UTF-8"
          body = response.body
        end
        expect(body.encoding).to eq(Encoding::UTF_8)
      end

      it "should ignore body_encoding= set after the request returns, like Net::HTTP" do
        stub_request(:get, "www.example.com").to_return(body: utf8_body)
        response = get_response
        response.body_encoding = "UTF-8"
        expect(response.body.encoding).to eq(Encoding::BINARY)
      end

      it "should apply the encoding to a string passed to read_body" do
        stub_request(:get, "www.example.com").to_return(body: utf8_body, headers: {"Content-Type" => "text/plain; charset=utf-8"})
        buffer = String.new
        get_response(true) { |response| response.read_body(buffer) }
        expect(buffer.encoding).to eq(Encoding::UTF_8)
      end

      it "should detect the encoding from the bytes of a body stubbed with another encoding" do
        body = "<p>caf\xE9</p>".dup.force_encoding(Encoding::UTF_8)
        stub_request(:get, "www.example.com").to_return(body: body, headers: {"Content-Type" => "application/xml"})
        expect(get_response(true).body.encoding).to eq(Encoding::UTF_8)
      end

      it "should leave a frozen body assigned in the request block as it is" do
        stub_request(:get, "www.example.com").to_return(body: utf8_body, headers: {"Content-Type" => "text/plain; charset=utf-8"})
        response = get_response(true) { |r| r.body = "replaced".freeze }
        expect(response.body).to eq("replaced")
      end

      it "should keep the encoding Net::HTTP gives a real response", net_connect: true do
        WebMock.allow_net_connect!
        http = Net::HTTP.new("localhost", port)
        http.response_body_encoding = "ISO-8859-1"
        expect(http.request(Net::HTTP::Get.new("/")).body.encoding).to eq(Encoding::ISO_8859_1)
      end

      it "should not change the encoding of the stubbed body" do
        stub_request(:get, "www.example.com").to_return(body: utf8_body, headers: {"Content-Type" => "text/plain; charset=utf-8"})
        get_response(true).body
        expect(get_response.body.encoding).to eq(Encoding::BINARY)
      end
    end
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

  it "should support method calls on stubbed socket" do
    WebMock.allow_net_connect!
    stub_request(:get, 'www.google.com')#.with(headers: {"My-Header" => 99})
    req = Net::HTTP::Get.new('/')
    Net::HTTP.start('www.google.com') do |http|
      http.request(req, '')
      socket = http.instance_variable_get(:@socket)
      expect(socket).to be_a(StubSocket)
      expect { socket.io.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1) }.to_not raise_error
    end
  end

  if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.7.0')
    it "uses the StubSocket to provide IP address" do
      Net::HTTP.start("example.com") do |http|
        expect(http.ipaddr).to eq("127.0.0.1")
      end
    end
  end

  it "defines common socket methods" do
    Net::HTTP.start("example.com") do |http|
      socket = http.instance_variable_get(:@socket)
      expect(socket.io.ssl_version).to eq("TLSv1.3")
      expect(socket.io.cipher).to eq(["TLS_AES_128_GCM_SHA256", "TLSv1.3", 128, 128])
    end
  end

  describe "using a Net::HTTP object created while WebMock was enabled, after WebMock is disabled" do
    let(:http) { Net::HTTP.new("localhost", port) }

    before do
      stub_request(:get, "http://localhost:#{port}/").to_return(body: "stubbed")
      http
      WebMock.disable!
    end

    after do
      http.finish if http.started?
      WebMock.enable!
    end

    it "connects for real when started" do
      http.start
      expect(http.instance_variable_get(:@socket)).to be_a(Net::BufferedIO)
    end

    it "makes a real request instead of returning the stubbed response" do
      expect(http.request(Net::HTTP::Get.new("/")).body).to eq("hello world")
    end

    it "makes a real request on a connection started while WebMock was enabled" do
      WebMock.enable!
      http.start
      WebMock.disable!
      expect(http.request(Net::HTTP::Get.new("/")).body).to eq("hello world")
    end

    it "raises the connection error again when a failed reconnect is retried" do
      closed_port = TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
      WebMock.enable!
      unreachable = Net::HTTP.new("127.0.0.1", closed_port)
      unreachable.start
      WebMock.disable!

      2.times do
        expect { unreachable.request(Net::HTTP::Get.new("/")) }.to raise_error(Errno::ECONNREFUSED)
      end
    end

    it "returns stubbed responses again once WebMock is enabled again" do
      http.start
      expect(http.request(Net::HTTP::Get.new("/")).body).to eq("hello world")
      real_socket = http.instance_variable_get(:@socket)

      WebMock.enable!

      expect(http.request(Net::HTTP::Get.new("/")).body).to eq("stubbed")
      expect(real_socket).to be_closed
    end
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

      it "should connect to the server on start when allowlisted", net_connect: true do
        WebMock.disable_net_connect!(allow: "www.google.com", net_http_connect_on_start: "www.google.com")
        @http.start {|conn|
          cert = OpenSSL::X509::Certificate.new conn.peer_cert
          expect(cert).to be_a(OpenSSL::X509::Certificate)
        }
      end

      it "should not connect to the server on start when not allowlisted", net_connect: true do
        WebMock.disable_net_connect!(allow: "www.google.com", net_http_connect_on_start: "www.yahoo.com")
        @http.start {|conn|
          expect(conn.peer_cert).to be_nil
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

  describe "when net_http_connect_on_start is a specific host" do
    before(:each) do
      WebMock.allow_net_connect!(net_http_connect_on_start: "localhost")
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

  describe "hostname handling" do
    it "should set brackets around the hostname if it is an IPv6 address" do
      net_http = Net::HTTP.new('b2dc:5bdf:4f0d::3014:e0ca', 80)
      path = '/example.jpg'
      expect(WebMock::NetHTTPUtility.get_uri(net_http, path)).to eq('http://[b2dc:5bdf:4f0d::3014:e0ca]:80/example.jpg')
    end

    it "should not set brackets around the hostname if it is already wrapped by brackets" do
      net_http = Net::HTTP.new('[b2dc:5bdf:4f0d::3014:e0ca]', 80)
      path = '/example.jpg'
      expect(WebMock::NetHTTPUtility.get_uri(net_http, path)).to eq('http://[b2dc:5bdf:4f0d::3014:e0ca]:80/example.jpg')
    end

    it "should not set brackets around the hostname if it is an IPv4 address" do
      net_http = Net::HTTP.new('181.152.137.168', 80)
      path = '/example.jpg'
      expect(WebMock::NetHTTPUtility.get_uri(net_http, path)).to eq('http://181.152.137.168:80/example.jpg')
    end

    it "should not set brackets around the hostname if it is a domain" do
      net_http = Net::HTTP.new('www.example.com', 80)
      path = '/example.jpg'
      expect(WebMock::NetHTTPUtility.get_uri(net_http, path)).to eq('http://www.example.com:80/example.jpg')
    end

    it "does not require a path" do
      net_http = Net::HTTP.new('www.example.com', 80)
      expect(WebMock::NetHTTPUtility.get_uri(net_http)).to eq('http://www.example.com:80')
    end
  end
end
