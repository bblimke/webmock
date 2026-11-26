require "spec_helper"
require "logger"
require "zlib"
require "acceptance/webmock_shared"
require "acceptance/http_rb/http_rb_spec_helper"

describe "HTTP.rb" do
  include HttpRbSpecHelper

  include_examples "with WebMock", :no_status_message

  context "streaming body" do
    let(:response) { HTTP.get "http://example.com" }
    before { stub_simple_request "example.com", 302, {}, "abc" }

    it "works as if it was streamed from socket" do
      expect(response.body.readpartial 1).to eq "a"
    end

    it "fails if body was already streamed" do
      response.body.to_s
      expect { response.body.readpartial 1 }.to raise_error(HTTP::StateError)
    end
  end

  context "without following redirects" do
    let(:response) { http_request(:get, "http://example.com") }
    let(:headers)  { response.headers }

    it "stops on first request" do
      stub_simple_request("example.com", 302, "Location" => "http://www.example.com")
      stub_simple_request("www.example.com")

      expect(headers).to include "Host" => "example.com"
    end
  end

  context "following redirects" do
    let(:options)  { { follow: true } }
    let(:response) { http_request(:get, "http://example.com", options) }
    let(:headers)  { response.headers }

    it "returns response of destination" do
      stub_simple_request("example.com", 302, "Location" => "http://www.example.com")
      stub_simple_request("www.example.com")

      expect(headers).to include "Host" => "www.example.com"
    end
  end

  context "restored request uri on replayed response object" do
    it "keeps non-default port" do
      stub_request :get, "example.com:1234/foo"
      response = HTTP.get "http://example.com:1234/foo"

      expect(response.uri.to_s).to eq "http://example.com:1234/foo"
    end

    it "does not injects default port" do
      stub_request :get, "example.com/foo"
      response = HTTP.get "http://example.com/foo"

      expect(response.uri.to_s).to eq "http://example.com/foo"
    end

    it "strips out default port even if it was explicitly given" do
      stub_request :get, "example.com/foo"
      response = HTTP.get "http://example.com:80/foo"

      expect(response.uri.to_s).to eq "http://example.com/foo"
    end
  end

  context "streamer" do
    it "can be read to a provided buffer" do
      stub_request(:get, "example.com/foo")
        .to_return(body: "Hello world! ")
      response = HTTP.get "http://example.com/foo"

      buffer = ""
      response.body.readpartial(1024, buffer)

      expect(buffer).to eq "Hello world! "
    end

    it "can be closed" do
      stub_request :get, "example.com/foo"
      response = HTTP.get "http://example.com/foo"

      response.connection.close
    end

    it "reports request finish" do
      stub_request(:get, "example.com/foo")
        .to_return(body: 'XX')
      response = HTTP.get "http://example.com/foo"

      expect(response.connection.finished_request?).to be(false)

      response.body.readpartial(1)
      expect(response.connection.finished_request?).to be(false)

      response.body.readpartial
      expect(response.connection.finished_request?).to be(true)
    end
  end

  it "should preserve request body encoding when matching requests" do
    stub_request(:post, "www.example.com").with(body: (lambda {|body|
      body.encoding == Encoding::UTF_8
    }))
    http_request(:post, "http://www.example.com/", body: "abc")
  end

  describe "features", if: defined?(HTTP::Features::Instrumentation) do
    include LocalHTTPServer

    # Records the events of the instrumentation feature, which HTTP.rb 6
    # sends as blocks and older versions as start and finish calls.
    let(:instrumenter) do
      Class.new do
        attr_reader :events

        def initialize
          @events = []
        end

        def instrument(name, payload = {})
          @events << name
          yield payload if block_given?
        end

        def start(name, _payload)
          @events << "#{name} start"
        end

        def finish(name, _payload)
          @events << "#{name} finish"
        end
      end.new
    end

    def instrumented_get(url)
      HTTP.use(instrumentation: {instrumenter: instrumenter}).get(url).to_s
    end

    after { WebMock.disable_net_connect! }

    it "emit the same instrumentation events for a stubbed request as for a real one" do
      WebMock.disable_net_connect!(allow_localhost: true)
      instrumented_get("http://#{WebMockServer.instance.host_with_port}/")
      real_events = instrumenter.events.dup
      instrumenter.events.clear

      stub_request(:get, "www.example.com")
      instrumented_get("http://www.example.com/")

      expect(real_events).to include("start_request.http")
      expect(instrumenter.events).to eq(real_events)
    end

    it "emit no error event for a stubbed 500 that a feature raises for, as for a real one",
      if: defined?(HTTP::Features::RaiseError) do
      client = HTTP.use(:raise_error, instrumentation: {instrumenter: instrumenter})
      capture_requests(response: "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\nConnection: close\r\n\r\n") do |port|
        expect { client.get("http://127.0.0.1:#{port}/") }.to raise_error(HTTP::StatusError)
      end
      real_events = instrumenter.events.dup
      instrumenter.events.clear

      stub_request(:get, "www.example.com").to_return(status: 500)
      expect { client.get("http://www.example.com/") }.to raise_error(HTTP::StatusError)

      expect(real_events).not_to include("error.http")
      expect(instrumenter.events).to eq(real_events)
    end

    it "return the stubbed response whatever an instrumenter returns, and when it doesn't yield" do
      returns_nil = Class.new do
        def instrument(_name, payload = {})
          yield payload if block_given?
          nil
        end

        def start(*); end

        def finish(*); end
      end
      doesnt_yield = Class.new(returns_nil) do
        def instrument(_name, _payload = {})
          nil
        end
      end
      stub_request(:get, "www.example.com").to_return(body: "stubbed")

      bodies = [returns_nil, doesnt_yield].map do |instrumenter|
        HTTP.use(instrumentation: {instrumenter: instrumenter.new}).get("http://www.example.com/").to_s
      end

      expect(bodies).to eq(["stubbed", "stubbed"])
    end

    it "emit the error event for a stubbed timeout" do
      stub_request(:get, "www.example.com").to_timeout

      expect { instrumented_get("http://www.example.com/") }.to raise_error(HTTP::TimeoutError)
      expect(instrumenter.events).to include("error.http")
    end

    it "don't run features other than instrumentation for a stubbed request, such as digest auth",
      if: defined?(HTTP::Features::DigestAuth) do
      challenge = 'Digest realm="webmock", nonce="abc", qop="auth"'
      stub_request(:get, "www.example.com").to_return(status: 401, headers: {"WWW-Authenticate" => challenge})

      response = HTTP.digest_auth(user: "user", pass: "pass").get("http://www.example.com/")

      expect(response.code).to eq(401)
      expect(a_request(:get, "www.example.com")).to have_been_made.once
    end
  end

  # HTTP.rb 3 has the feature, but a stubbed request with any feature fails there.
  describe "auto_inflate feature",
    if: defined?(HTTP::Features::AutoInflate) && HTTP::Feature.method_defined?(:wrap_response) do
    include LocalHTTPServer

    # A character of several bytes tells the size of the body from its length.
    let(:inflated) { (%({"snow":"\u96ea"}) * 20).b }
    let(:gzipped) { Zlib.gzip(inflated) }
    let(:client) { HTTP.use(:auto_inflate) }

    def compressed_response(body = gzipped, encoding: "gzip", length: body.bytesize, fields: "")
      head = "HTTP/1.1 200 OK\r\nContent-Type: application/json; charset=utf-8\r\n#{fields}" \
        "Content-Encoding: #{encoding}\r\nContent-Length: #{length}\r\nConnection: close\r\n\r\n"
      head.b + body
    end

    def stub_with(recorded, verb = :get)
      stub_request(verb, "www.example.com").
        to_return(status: recorded.status, headers: recorded.headers, body: recorded.body)
    end

    # Makes a real request and returns HTTP.rb's response and the one an
    # after_request callback got for it.
    def real_and_recorded_response(client, verb = :get, response = compressed_response)
      recorded = nil
      WebMock.after_request(real_requests_only: true) { |_, webmock_response| recorded = webmock_response }
      real = nil
      capture_requests(response: response) { |port| real = client.request(verb, "http://127.0.0.1:#{port}/") }
      [real, recorded]
    end

    after { WebMock.reset_callbacks }

    {"gzip" => :gzip, "x-gzip" => :gzip, "deflate" => :deflate}.each do |encoding, compress|
      it "gives callbacks the inflated body of a real #{encoding} response with headers that describe it" do
        response = compressed_response(Zlib.public_send(compress, inflated), encoding: encoding)
        _, recorded = real_and_recorded_response(client, :get, response)

        expect(recorded.body.b).to eq(inflated)
        expect(recorded.headers).to eq(
          "Content-Type" => "application/json; charset=utf-8",
          "Content-Length" => inflated.bytesize.to_s,
          "Connection" => "close"
        )
      end
    end

    # HTTP.rb 6 reads the inflated body through its logging feature's stream.
    it "gives callbacks headers that describe the body when another feature wraps the inflated one",
      if: HTTP::VERSION >= "6.0.0" do
      logging = HTTP.use(logging: {logger: Logger.new(File::NULL)}).use(:auto_inflate)
      _, recorded = real_and_recorded_response(logging)

      expect(recorded.body.b).to eq(inflated)
      expect(recorded.headers).to include("Content-Length" => inflated.bytesize.to_s)
      expect(recorded.headers).not_to include("Content-Encoding")
    end

    it "returns the real body for a stub made of what callbacks got for a real response" do
      _, recorded = real_and_recorded_response(client)
      stub_with(recorded)

      expect(client.get("http://www.example.com/").to_s.b).to eq(inflated)
    end

    it "gives callbacks headers that describe a body that is still compressed once inflated" do
      real, recorded = real_and_recorded_response(client, :get, compressed_response(Zlib.gzip(gzipped)))
      stub_with(recorded)

      expect(real.to_s.b).to eq(gzipped)
      expect(recorded.body.b).to eq(gzipped)
      expect(recorded.headers).to include("Content-Length" => gzipped.bytesize.to_s)
      expect(recorded.headers).not_to include("Content-Encoding")
      expect(client.get("http://www.example.com/").to_s.b).to eq(gzipped)
    end

    it "gives callbacks no Content-Length for a real response that has none" do
      chunked = "HTTP/1.1 200 OK\r\nContent-Encoding: gzip\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n".b +
        "#{gzipped.bytesize.to_s(16)}\r\n".b + gzipped + "\r\n0\r\n\r\n".b
      _, recorded = real_and_recorded_response(client, :get, chunked)

      expect(recorded.body.b).to eq(inflated)
      expect(recorded.headers).to eq("Transfer-Encoding" => "chunked", "Connection" => "close")
    end

    it "leaves the real response as HTTP.rb returns it, with the headers of the compressed body" do
      real, _ = real_and_recorded_response(client)

      expect(real.body.readpartial.b).to eq(inflated)
      expect(real.headers.to_h).to include("Content-Encoding" => "gzip", "Content-Length" => gzipped.bytesize.to_s)
    end

    it "asks nothing of the feature for a body it can see was inflated" do
      feature = HTTP::Features::AutoInflate.new
      expect(feature).to receive(:wrap_response).once.and_call_original
      _, recorded = real_and_recorded_response(HTTP.use(auto_inflate: feature))

      expect(recorded.headers).not_to include("Content-Encoding")
    end

    # HTTP.rb 6 applies the features to a response from the last to the first.
    it "keeps the headers when another feature's stream reads the inflated body and compresses it again",
      if: HTTP::VERSION >= "6.0.0" do
      repacking = Class.new do
        def initialize(body)
          @stream = body
        end

        def readpartial(size = 16_384, *args)
          @deflated ||= StringIO.new(Zlib.deflate(@stream.to_s))
          @deflated.readpartial(size, *args)
        end
      end
      repack = Class.new(HTTP::Feature) do
        define_method(:wrap_response) do |response|
          HTTP::Response.new(status: response.code, version: response.version, headers: response.headers,
            request: response.request, body: HTTP::Response::Body.new(repacking.new(response.body)))
        end
      end
      repacked = HTTP.use(repack: repack.new).use(:auto_inflate)
      deflated = Zlib.deflate(inflated)
      real, recorded = real_and_recorded_response(repacked, :get, compressed_response(deflated, encoding: "deflate"))
      stub_with(recorded)

      expect(real.to_s.b).to eq(deflated)
      expect(recorded.headers).to include("Content-Encoding" => "deflate")
      expect(repacked.get("http://www.example.com/").to_s.b).to eq(deflated)
    end

    # A body of a feature's own kind may do anything with what it reads, and
    # say anything of itself.
    it "keeps the headers when a subclass of HTTP.rb's body reads the inflated body and compresses it again",
      if: HTTP::VERSION >= "6.0.0" do
      deflating = Class.new(HTTP::Response::Body) do
        def to_s
          Zlib.deflate(super)
        end

        def instance_of?(_class)
          true
        end
      end
      repack = Class.new(HTTP::Feature) do
        define_method(:wrap_response) do |response|
          HTTP::Response.new(status: response.code, version: response.version, headers: response.headers,
            request: response.request, body: deflating.new(response.body.instance_variable_get(:@stream)))
        end
      end
      repacked = HTTP.use(repack: repack.new).use(:auto_inflate)
      deflated = Zlib.deflate(inflated)
      _, recorded = real_and_recorded_response(repacked, :get, compressed_response(deflated, encoding: "deflate"))
      stub_with(recorded)

      expect(recorded.body.b).to eq(deflated)
      expect(recorded.headers).to include("Content-Encoding" => "deflate", "Content-Length" => deflated.bytesize.to_s)
      expect(repacked.get("http://www.example.com/").to_s.b).to eq(deflated)
    end

    # A subclass may do anything with the headers and the body.
    it "keeps the headers as they were when the feature is a subclass of HTTP.rb's" do
      real, recorded = real_and_recorded_response(HTTP.use(subclass: Class.new(HTTP::Features::AutoInflate).new))

      expect(real.to_s.b).to eq(inflated)
      expect(recorded.body.b).to eq(inflated)
      expect(recorded.headers).to include("Content-Encoding" => "gzip", "Content-Length" => gzipped.bytesize.to_s)
    end

    it "asks a real response for its body once" do
      calls = 0
      counting = Class.new(HTTP::Feature) do
        define_method(:wrap_response) do |response|
          response.define_singleton_method(:body) do
            calls += 1
            super()
          end
          response
        end
      end
      # HTTP.rb 6 applies the features to a response from the last to the first.
      features = [:auto_inflate, {counting: counting.new}]
      features.reverse! if HTTP::VERSION >= "6.0.0"
      _, recorded = real_and_recorded_response(features.inject(HTTP) { |client, feature| client.use(feature) })

      expect(recorded.headers).not_to include("Content-Encoding")
      expect(calls).to eq(1)
    end

    # HTTP.rb 4 raises Zlib::BufError when it inflates an empty body.
    context "for a real response with an empty body", if: HTTP::VERSION >= "5.0.0" do
      it "keeps the headers when the body inflates to nothing" do
        nothing = Zlib.gzip("")
        _, recorded = real_and_recorded_response(client, :get, compressed_response(nothing))
        stub_with(recorded)

        expect(recorded.body).to eq("")
        expect(recorded.headers).to include("Content-Encoding" => "gzip", "Content-Length" => nothing.bytesize.to_s)
        expect(client.get("http://www.example.com/").to_s).to eq("")
      end

      it "keeps the headers of a response to HEAD" do
        response = compressed_response("", length: gzipped.bytesize)
        _, recorded = real_and_recorded_response(client, :head, response)
        stub_with(recorded, :head)

        expect(recorded.headers).to include("Content-Encoding" => "gzip", "Content-Length" => gzipped.bytesize.to_s)
        expect(client.head("http://www.example.com/").to_s).to eq("")
      end

      {204 => "No Content", 304 => "Not Modified"}.each do |code, reason|
        it "keeps the headers of a #{code} response" do
          response = "HTTP/1.1 #{code} #{reason}\r\nContent-Encoding: gzip\r\nConnection: close\r\n\r\n"
          _, recorded = real_and_recorded_response(client, :get, response)
          stub_with(recorded)

          expect(recorded.headers).to include("Content-Encoding" => "gzip")
          expect(client.get("http://www.example.com/").to_s).to eq("")
        end
      end
    end

    # HTTP.rb 6's caching feature returns the body as a String, which doesn't
    # show that auto_inflate, which has to come after it, inflated it.
    it "keeps the headers as they were for a real response that the caching feature returns",
      if: defined?(HTTP::Features::Caching) do
      response = compressed_response(fields: "Cache-Control: max-age=60\r\n")
      real, recorded = real_and_recorded_response(HTTP.use(:caching, :auto_inflate), :get, response)

      expect(real.to_s.b).to eq(inflated)
      expect(recorded.body.b).to eq(inflated)
      expect(recorded.headers).to include("Content-Encoding" => "gzip", "Content-Length" => gzipped.bytesize.to_s)
    end

    it "keeps the headers of a compressed body of a real response without the feature" do
      _, recorded = real_and_recorded_response(HTTP)

      expect(recorded.body.b).to eq(gzipped)
      expect(recorded.headers).to include("Content-Encoding" => "gzip", "Content-Length" => gzipped.bytesize.to_s)
    end

    it "keeps the headers of a real response in an encoding the feature doesn't inflate" do
      _, recorded = real_and_recorded_response(client, :get, compressed_response("not inflated", encoding: "br"))

      expect(recorded.body).to eq("not inflated")
      expect(recorded.headers).to include("Content-Encoding" => "br", "Content-Length" => "12")
    end

    it "keeps the headers of a compressed body that a feature of this kind left alone" do
      leaves_alone = Class.new(HTTP::Features::AutoInflate) do
        def wrap_response(response)
          response
        end
      end
      _, recorded = real_and_recorded_response(HTTP.use(leaves_alone: leaves_alone.new))

      expect(recorded.body.b).to eq(gzipped)
      expect(recorded.headers).to include("Content-Encoding" => "gzip", "Content-Length" => gzipped.bytesize.to_s)
    end

    it "inflates the compressed body of a stub" do
      stub_request(:get, "www.example.com").to_return(body: gzipped, headers: {"Content-Encoding" => "gzip"})

      expect(client.get("http://www.example.com/").to_s.b).to eq(inflated)
    end
  end

  describe "when making real requests", net_connect: true do
    before do
      WebMock.allow_net_connect!
    end

    it "should allow streaming the response body" do
      response = HTTP.get("http://localhost:#{WebMockServer.instance.port}")

      read_body = ""
      response.body.each do |chunk|
        read_body << chunk
      end

      expect(read_body).to eql("hello world")
    end
  end
end
