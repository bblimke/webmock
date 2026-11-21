require "spec_helper"
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
        .to_return(status: 200, body: "Hello world! ")
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
