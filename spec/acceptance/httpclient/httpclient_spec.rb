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

  it "should yield block on response if block provided" do
    stub_request(:get, "www.example.com").to_return(:body => "abc")
    response_body = ""
    http_request(:get, "http://www.example.com/") do |body|
      response_body = body
    end
    response_body.should == "abc"
  end

  it "should match requests if headers are the same  but in different order" do
    stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]} )
    http_request(
      :get, "http://www.example.com/",
    :headers => {"a" => ["c", "b"]}).status.should == "200"
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
    str.should == 'test'
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
      @client.request(:get, 'http://www.example.com/').status.should == 200
    end

    it "supports response filters" do
      res = @client.request(:get, 'http://www.example.com/')
      res.header['X-Powered-By'].first.should == 'webmock'
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

      # To make two requests that have the same request signature, the headers must match.
      # Since the webmock server has a Set-Cookie header, the 2nd request will automatically
      # include a Cookie header (due to how httpclient works), so we have to set the header
      # manually on the first request but not on the 2nd request.
      http_request(:get, webmock_server_url, :client => client,
                         :headers => { "Cookie" => "bar=; foo=" })
      http_request(:get, webmock_server_url, :client => client)

      request_signatures.should have(2).signatures
      # Verify the request signatures were identical as needed by this example
      request_signatures.first.should eq(request_signatures.last)
    end
  end

  context 'session headers' do

    it "client sends a User-Agent header when given an agent_name explicitly to the client" do
      user_agent = "Client/0.1"
      stub_request(:get, "www.example.com").with(:headers => { 'User-agent' => "#{user_agent} #{HTTPClient::LIB_NAME}" })
      HTTPClient.new(:agent_name => user_agent).get("www.example.com")
    end

    it "client sends the Accept, User-Agent, and Date by default" do
      stub_request(:get, "www.example.com").with do |req|
        req.headers["Accept"].should == "*/*"
        req.headers["User-Agent"].should == "#{HTTPClient::DEFAULT_AGENT_NAME} #{HTTPClient::LIB_NAME}"
        req.headers["Date"].should_not be_nil
      end
      http_request(:get, "www.example.com")
    end

    it "explicitly defined headers take precedence over session defaults" do
      headers = { 'Accept'  => 'foo/bar', 'User-Agent' => 'custom', 'Date' => 'today' }
      stub_request(:get, "www.example.com").with(:headers => headers)
      HTTPClient.new.get("www.example.com", nil, headers)
    end

  end

end
