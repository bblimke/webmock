require 'spec_helper'
require 'acceptance/webmock_shared'
require 'ostruct'

require 'acceptance/httpclient/httpclient_spec_helper'

describe "HTTPClient" do
  include HTTPClientSpecHelper

  before(:each) do
    WebMock.reset_callbacks
    HTTPClientSpecHelper.async_mode = false
  end

  include_examples "with WebMock"

  it "should raise a clearly readable error if request with multipart body is sent" do
    stub_request(:post, 'www.example.com').with(:body => {:type => 'image'})

    expect {
      HTTPClient.new.post_content('www.example.com', :type => 'image', :file => File.new('spec/fixtures/test.txt'))
    }.to raise_error(ArgumentError, "WebMock does not support matching body for multipart/form-data requests yet :(")
  end

  it "should yield block on response if block provided" do
    stub_request(:get, "www.example.com").to_return(:body => "abc")
    response_body = ""
    http_request(:get, "http://www.example.com/") do |body|
      response_body = body
    end
    expect(response_body).to eq("abc")
  end

  it "should match requests if headers are the same  but in different order" do
    stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]} )
    expect(http_request(
      :get, "http://www.example.com/",
    :headers => {"a" => ["c", "b"]}).status).to eq("200")
  end

  describe "when using async requests" do
    before(:each) do
      HTTPClientSpecHelper.async_mode = true
    end

    include_examples "with WebMock"
  end

  it "should work with get_content" do
    stub_request(:get, 'www.example.com').to_return(:status => 200, :body => 'test', :headers => {})
    str = ''
    HTTPClient.get_content('www.example.com') do |content|
      str << content
    end
    expect(str).to eq('test')
  end

  it "should work via JSONClient subclass" do
    stub_request(:get, 'www.example.com').to_return(
      :status => 200,
      :body => '{"test": "foo"}',
      :headers => {'Content-Type' => 'application/json'}
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

    let(:make_request) {HTTPClient.new.post("http://www.example.com", :body => body, :header => header)}

    before do
      stub_request(:post, "www.example.com")
    end

    it "should work with multipart bodies" do
      make_request
    end
  end


  context "Filters" do
    class Filter
      def filter_request(request)
        request.header["Authorization"] = "Bearer 0123456789"
      end

      def filter_response(request, response)
        response.header.set('X-Powered-By', 'webmock')
      end
    end

    before do
      @client = HTTPClient.new
      @client.request_filter << Filter.new
      stub_request(:get, 'www.example.com').with(:headers => {'Authorization' => 'Bearer 0123456789'})
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
      request_signatures = []
      WebMock.globally_stub_request do |request_sig|
        request_signatures << request_sig
        nil # to let the request be made for real
      end

      http_request(:get, webmock_server_url, :client => client, :headers => { "Cookie" => "bar=; foo=" })

      if defined? HTTP::CookieJar
        http_request(:get, webmock_server_url, :client => client, :headers => { "Cookie" => "bar=; foo=" })
      else
        # If http-cookie is not present, then the cookie headers will saved between requests
        http_request(:get, webmock_server_url, :client => client)
      end

      expect(request_signatures.size).to eq(2)
      # Verify the request signatures were identical as needed by this example
      expect(request_signatures.first).to eq(request_signatures.last)
    end
  end

  context 'session headers' do
    it "client sends a User-Agent header when given an agent_name explicitly to the client" do
      user_agent = "Client/0.1"
      stub_request(:get, "www.example.com").with(:headers => { 'User-agent' => "#{user_agent} #{HTTPClient::LIB_NAME}" })
      HTTPClient.new(:agent_name => user_agent).get("www.example.com")
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
      stub_request(:get, "www.example.com").with(:headers => headers)
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

  context 'httpclient streams response' do
    before do
      WebMock.allow_net_connect!
      WebMock.after_request(:except => [:other_lib])  do |_, response|
        @response = response
      end
    end

    it 'sets the full body on the webmock response' do
      body = ''
      result = HTTPClient.new.request(:get, 'http://www.example.com/') do |http_res, chunk|
        body += chunk
      end
      expect(@response.body).to eq body
    end
  end

  context 'credentials' do
    it 'are detected when manually specifying Authorization header' do
      stub_request(:get, 'username:password@www.example.com').to_return(:status => 200)
      headers = {'Authorization' => 'Basic dXNlcm5hbWU6cGFzc3dvcmQ='}
      expect(http_request(:get, 'http://www.example.com/', {:headers => headers}).status).to eql('200')
    end
  end
end
