require 'spec_helper'
require 'acceptance/webmock_shared'
require 'ostruct'

require 'acceptance/httpclient/httpclient_spec_helper'

# FIXME: HTTPClient on JRuby seems to have ordering/concurrency issues with these tests
describe "HTTPClient", if: !(RUBY_PLATFORM =~ /java/) do
  include HTTPClientSpecHelper

  before(:each) do
    WebMock.reset_callbacks
    HTTPClientSpecHelper.async_mode = false
  end

  include_examples "with WebMock"

  it "should raise a clearly readable error if request with multipart body is sent" do
    stub_request(:post, 'www.example.com').with(body: {type: 'image'})

    expect {
      HTTPClient.new.post_content('www.example.com', type: 'image', file: File.new('spec/fixtures/test.txt'))
    }.to raise_error(ArgumentError, "WebMock does not support matching body for multipart/form-data requests yet :(")
  end

  it "should yield block on response if block provided" do
    stub_request(:get, "www.example.com").to_return(body: "abc")
    response_body = ""
    http_request(:get, "http://www.example.com/") do |body|
      response_body = body
    end
    expect(response_body).to eq("abc")
  end

  it "should not yield block on empty response if block provided" do
    stub_request(:get, "www.example.com").to_return(body: "")
    response_body = ""
    http_request(:get, "http://www.example.com/"){ raise }
    expect(response_body).to eq("")
  end

  it "should match requests if headers are the same  but in different order" do
    stub_request(:get, "www.example.com").with(headers: {"a" => ["b", "c"]} )
    expect(http_request(
      :get, "http://www.example.com/",
    headers: {"a" => ["c", "b"]}).status).to eq("200")
  end

  describe "when using async requests" do
    before(:each) do
      HTTPClientSpecHelper.async_mode = true
    end

    include_examples "with WebMock"

    it "lists a stubbed async request when it is made, not when its thread runs" do
      stub_request(:get, /www\.example\.com/)
      client = HTTPClient.new
      connection = client.get_async("http://www.example.com/first")
      client.get("http://www.example.com/second")
      connection.pop
      expect(WebMock.executed_requests.map { |request| request.uri.path }).to eq(["/first", "/second"])
    end

    it "records the async request before its response block makes another request" do
      client = HTTPClient.new
      stub_request(:get, "www.example.com/inner")
      stub_request(:get, "www.example.com/outer").to_return do
        client.get("http://www.example.com/inner")
        {body: "outer"}
      end
      connection = client.get_async("http://www.example.com/outer")
      connection.join
      expect(connection.pop.content.read).to eq("outer")
      expect(executed_requests.map { |request| request.uri.path }).to eq(["/outer", "/inner"])
    end

    it "records and counts the request ID sent on a real async request" do
      WebMock.allow_net_connect!
      server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: 0,
        Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      server.mount_proc("/") { |req, res| res.body = req["X-Request-Id"] }
      thread = Thread.new { server.start }
      url = "http://127.0.0.1:#{server.config[:Port]}/"
      client = HTTPClient.new
      filter = double("request ID filter", filter_response: nil)
      next_id = 0
      allow(filter).to receive(:filter_request) do |req|
        req.header.set("X-Request-Id", (next_id += 1).to_s)
      end
      client.request_filter << filter

      connection = client.get_async(url)
      connection.join
      sent_id = connection.pop.content.read
      expect(sent_id).to eq("1")
      expect(executed_requests.map { |req| req.headers["X-Request-Id"] }).to eq([sent_id])
      expect(a_request(:get, url).with(headers: {"X-Request-Id" => sent_id})).to have_been_made.once
    ensure
      server.shutdown if server
      thread.join if thread
    end

    it "records the whole response when the caller reads part of the async stream before joining" do
      WebMock.allow_net_connect!
      callback_bodies = []
      WebMock.after_request { |_, response| callback_bodies << response.body }
      send_remainder = Queue.new
      server = WEBrick::HTTPServer.new(BindAddress: "127.0.0.1", Port: 0,
        Logger: WEBrick::Log.new(File::NULL), AccessLog: [])
      server.mount_proc("/") do |_, response|
        response["Content-Length"] = "6"
        response.body = proc do |out|
          out.write("abc")
          send_remainder.pop
          out.write("def")
        end
      end
      thread = Thread.new { server.start }
      Timeout.timeout(10) do
        connection = HTTPClient.new.get_async("http://127.0.0.1:#{server.config[:Port]}/")
        stream = connection.pop.content
        expect(stream.read(3)).to eq("abc")
        send_remainder << true
        connection.join
        expect(stream.read).to eq("def")
        expect(callback_bodies).to eq(["abcdef"])
      end
    ensure
      send_remainder << true if send_remainder
      server.shutdown if server
      thread.join if thread
    end

    it "delivers an async loopback response to both the callback and the caller" do
      WebMock.allow_net_connect!
      client = HTTPClient.new
      client.test_loopback_response << "loopback"
      callback_bodies = []
      WebMock.after_request { |_, response| callback_bodies << response.body }

      connection = client.get_async("http://localhost/")
      connection.join
      expect(callback_bodies).to eq(["loopback"])
      expect(connection.pop.content.read).to eq("loopback")
    end

    it "evaluates a stubbed response only once per async request even if the async thread starts early" do
      # Reproduces two races that made the async thread evaluate the stub registry again and consume
      # an extra response from the stub sequence: starting work before the caller finished wiring up
      # the connection, and rebuilding the request signature after the Date header (1 second resolution)
      # changed. Delaying #async_thread= beyond a second makes both interleavings deterministic;
      # only the first request needs it.
      connection_class = HTTPClient::Connection
      delays = [1.1]
      begin
        connection_class.class_eval do
          alias_method :async_thread_without_delay=, :async_thread=
          define_method(:async_thread=) do |thread|
            delay = delays.shift
            sleep delay if delay
            self.async_thread_without_delay = thread
          end
        end

        stub_request(:get, "www.example.com").to_raise(MyException).to_return(body: "2")

        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(MyException, "Exception from WebMock")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
      ensure
        connection_class.class_eval do
          alias_method :async_thread=, :async_thread_without_delay=
          remove_method :async_thread_without_delay=
        end
      end
    end
  end

  it "should work with get_content" do
    stub_request(:get, 'www.example.com').to_return(status: 200, body: 'test', headers: {})
    str = ''.dup
    HTTPClient.get_content('www.example.com') do |content|
      str << content
    end
    expect(str).to eq('test')
  end

  it "should work via JSONClient subclass" do
    stub_request(:get, 'www.example.com').to_return(
      status: 200,
      body: '{"test": "foo"}',
      headers: {'Content-Type' => 'application/json'}
    )
    content = JSONClient.get('www.example.com').content
    expect(content).to eq("test" => "foo")
  end

  context "multipart bodies" do
    let(:header) {{
        'Accept' => 'application/json',
        'Content-Type' => 'multipart/form-data'
    }}

   let(:body) {[
      {
        'Content-Type' => 'application/json',
        'Content-Disposition' => 'form-data',
        :content => '{"foo": "bar", "baz": 2}'
      }
    ]}

    let(:make_request) {HTTPClient.new.post("http://www.example.com", body: body, header: header)}

    before do
      stub_request(:post, "www.example.com")
    end

    it "should work with multipart bodies" do
      make_request
    end
  end


  context "with a query argument" do
    before do
      stub_request(:get, /www\.example\.com/)
    end

    it "adds the query argument to a URI without a query" do
      HTTPClient.new.get("http://www.example.com/", {"b" => "2"})

      expect(a_request(:get, "www.example.com/?b=2")).to have_been_made.once
    end

    it "keeps the URI query and adds the query argument" do
      HTTPClient.new.get("http://www.example.com/?a=1", {"b" => "2"})

      expect(a_request(:get, "www.example.com/?a=1&b=2")).to have_been_made.once
    end

    it "keeps the URI query when the query argument is an empty hash" do
      HTTPClient.new.get("http://www.example.com/?a=1", {})

      expect(a_request(:get, "www.example.com/?a=1")).to have_been_made.once
    end
  end

  context "Filters" do
    class Filter
      def filter_request(request)
        request.header["Authorization"] = "Bearer 0123456789"
        request.header.request_uri.query = "webmock=here"
      end

      def filter_response(request, response)
        response.header.set('X-Powered-By', 'webmock')
      end
    end

    before do
      @client = HTTPClient.new
      @client.request_filter << Filter.new
      stub_request(:get, 'www.example.com').with(
        query: {'webmock' => 'here'},
        headers: {'Authorization' => 'Bearer 0123456789'})
    end

    it "supports request filters" do
      expect(@client.request(:get, 'http://www.example.com/').status).to eq(200)
    end

    it "supports response filters" do
      res = @client.request(:get, 'http://www.example.com/')
      expect(res.header['X-Powered-By'].first).to eq('webmock')
    end
  end

  context 'when a client instance is re-used for another identical request' do
    let(:client) { HTTPClient.new }
    let(:webmock_server_url) {"http://#{WebMockServer.instance.host_with_port}/"}

    before { WebMock.allow_net_connect! }

    it 'invokes the global_stub_request hook for each request' do
      # Mock time to ensure that date headers match
      now = Time.now
      allow(Time).to receive(:now).and_return(now)

      request_signatures = []
      WebMock.globally_stub_request do |request_sig|
        request_signatures << request_sig
        nil # to let the request be made for real
      end

      http_request(:get, webmock_server_url, client: client, headers: { "Cookie" => "bar=; foo=" })

      if defined? HTTP::CookieJar
        http_request(:get, webmock_server_url, client: client, headers: { "Cookie" => "bar=; foo=" })
      else
        # If http-cookie is not present, then the cookie headers will saved between requests
        http_request(:get, webmock_server_url, client: client)
      end

      expect(request_signatures.size).to eq(2)
      # Verify the request signatures were identical as needed by this example
      expect(request_signatures.first).to eq(request_signatures.last)
    end
  end

  context 'session headers' do
    it "client sends a User-Agent header when given an agent_name explicitly to the client" do
      user_agent = "Client/0.1"
      stub_request(:get, "www.example.com").with(headers: { 'User-agent' => "#{user_agent} #{HTTPClient::LIB_NAME}" })
      HTTPClient.new(agent_name: user_agent).get("www.example.com")
    end

    it "client sends the Accept, User-Agent, and Date by default" do
      WebMock.disable_net_connect!
      stub_request(:get, "www.example.com").with do |req|
        req.headers["Accept"] == "*/*" &&
        req.headers["User-Agent"] == "#{HTTPClient::DEFAULT_AGENT_NAME} #{HTTPClient::LIB_NAME}" &&
        req.headers["Date"]
      end
      http_request(:get, "www.example.com")
    end

    it "explicitly defined headers take precedence over session defaults" do
      headers = { 'Accept'  => 'foo/bar', 'User-Agent' => 'custom', 'Date' => 'today' }
      stub_request(:get, "www.example.com").with(headers: headers)
      HTTPClient.new.get("www.example.com", nil, headers)
    end
  end

  context 'httpclient response header' do
    it 'receives request_method, request_uri, and request_query from the request header' do
      stub_request :get, 'www.example.com'
      message = HTTPClient.new.get 'www.example.com'
      expect(message.header.request_uri.to_s).to eq('www.example.com')
    end
  end

  context 'httpclient streams response', net_connect: true do
    before do
      WebMock.allow_net_connect!
      WebMock.after_request(except: [:other_lib])  do |_, response|
        @response = response
      end
    end

    it 'sets the full body on the webmock response' do
      body = ''
      HTTPClient.new.request(:get, 'http://www.example.com/') do |http_res, chunk|
        body += chunk
      end
      expect(@response.body).to eq body
    end
  end

  context 'credentials' do
    it 'are detected when manually specifying Authorization header' do
      stub_request(:get, "http://www.example.com/").with(basic_auth: ['username', 'password']).to_return(status: 200)

      headers = {'Authorization' => 'Basic dXNlcm5hbWU6cGFzc3dvcmQ='}
      expect(http_request(:get, 'http://www.example.com/', {headers: headers}).status).to eql('200')
    end
  end
end
