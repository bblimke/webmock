# encoding: utf-8
require 'spec_helper'
require 'acceptance/webmock_shared'
require 'ostruct'

unless RUBY_PLATFORM =~ /java/
  require 'acceptance/em_http_request/em_http_request_spec_helper'

  describe "EM::HttpRequest" do
    include EMHttpRequestSpecHelper

    include_context "with WebMock", :no_status_message

    #functionality only supported for em-http-request 1.x
    if defined?(EventMachine::HttpConnection)
      context 'when a real request is made and redirects are followed', :net_connect => true do
        before { WebMock.allow_net_connect! }

        # This url redirects to the https URL.
        let(:http_url) { "http://raw.github.com:80/gist/fb555cb593f3349d53af/6921dd638337d3f6a51b0e02e7f30e3c414f70d6/vcr_gist" }
        let(:https_url) { http_url.gsub('http', 'https').gsub('80', '443') }

        def make_request
          EM.run do
            request = EM::HttpRequest.new(http_url).get(:redirects => 1)
            request.callback { EM.stop }
          end
        end

        it "invokes the globally_stub_request hook with both requests" do
          urls = []
          WebMock.globally_stub_request { |r| urls << r.uri.to_s; nil }

          make_request

          expect(urls).to eq([http_url, https_url])
        end

        it 'invokes the after_request hook with both requests' do
          urls = []
          WebMock.after_request { |req, res| urls << req.uri.to_s }

          make_request

          expect(urls).to eq([http_url, https_url])
        end
      end

      describe "with middleware" do

        it "should work with request middleware" do
          stub_request(:get, "www.example.com").with(:body => 'bar')

          middleware = Class.new do
            def request(client, head, body)
              [{}, 'bar']
            end
          end

          EM.run do
            conn = EventMachine::HttpRequest.new('http://www.example.com/')

            conn.use middleware

            http = conn.get(:body => 'foo')

            http.callback do
              expect(WebMock).to have_requested(:get, "www.example.com").with(:body => 'bar')
              EM.stop
            end
          end
        end

        let(:response_middleware) do
          Class.new do
            def response(resp)
              resp.response = 'bar'
            end
          end
        end

        it "should work with response middleware" do
          stub_request(:get, "www.example.com").to_return(:body => 'foo')

          EM.run do
            conn = EventMachine::HttpRequest.new('http://www.example.com/')

            conn.use response_middleware

            http = conn.get

            http.callback do
              expect(http.response).to eq('bar')
              EM.stop
            end
          end
        end

        let(:webmock_server_url) { "http://#{WebMockServer.instance.host_with_port}/" }

        shared_examples_for "em-http-request middleware/after_request hook integration" do
          it 'yields the original raw body to the after_request hook even if a response middleware modifies the body' do
            yielded_response_body = nil
            ::WebMock.after_request do |request, response|
              yielded_response_body = response.body
            end

            EM::HttpRequest.use response_middleware

            EM.run do
              http = EventMachine::HttpRequest.new(webmock_server_url).get
              http.callback { EM.stop }
            end

            expect(yielded_response_body).to eq("hello world")
          end
        end

        context 'making a real request', :net_connect => true do
          before { WebMock.allow_net_connect! }
          include_examples "em-http-request middleware/after_request hook integration"
        end

        context 'when the request is stubbed' do
          before { stub_request(:get, webmock_server_url).to_return(:body => 'hello world') }
          include_examples "em-http-request middleware/after_request hook integration"
        end
      end

      it 'should trigger error callbacks asynchronously' do
        stub_request(:get, 'www.example.com').to_timeout
        called = false

        EM.run do
          conn = EventMachine::HttpRequest.new('http://www.example.com/')
          http = conn.get
          http.errback do
            called = true
            EM.stop
          end
          expect(called).to eq(false)
        end

        expect(called).to eq(true)
      end

      # not pretty, but it works
      if defined?(EventMachine::Synchrony)
        describe "with synchrony" do
          let(:webmock_em_http) { File.expand_path(File.join(File.dirname(__FILE__), "../lib/webmock/http_lib_adapters/em_http_request/em_http_request_1_x.rb")) }

          before(:each) do
            # need to reload the webmock em-http adapter after we require synchrony
            WebMock::HttpLibAdapters::EmHttpRequestAdapter.disable!
            $".delete webmock_em_http
            $".delete File.expand_path(File.join(File.dirname(__FILE__), "../../../lib/webmock/http_lib_adapters/em_http_request_adapter.rb"))
            require 'em-synchrony'
            require 'em-synchrony/em-http'
            require File.expand_path(File.join(File.dirname(__FILE__), "../../../lib/webmock/http_lib_adapters/em_http_request_adapter.rb"))
          end

          it "should work" do
            stub_request(:post, /.*.testserver.com*/).to_return(:status => 200, :body => 'ok')
            expect {
              EM.run do
                fiber = Fiber.new do
                  http = EM::HttpRequest.new("http://www.testserver.com").post :body => "foo=bar&baz=bang", :timeout => 60
                  EM.stop
                end
                fiber.resume
              end
            }.not_to raise_error
          end

          after(:each) do
            EM.send(:remove_const, :Synchrony)
            EM.send(:remove_const, :HTTPMethods)
            WebMock::HttpLibAdapters::EmHttpRequestAdapter.disable!
            $".reject! {|path| path.include? "em-http-request"}
            $".delete webmock_em_http
            $".delete File.expand_path(File.join(File.dirname(__FILE__), "../../../lib/webmock/http_lib_adapters/em_http_request_adapter.rb"))
            require 'em-http-request'
            require File.expand_path(File.join(File.dirname(__FILE__), "../../../lib/webmock/http_lib_adapters/em_http_request_adapter.rb"))
          end
        end
      end
    end

    it "should work with streaming" do
      stub_request(:get, "www.example.com").to_return(:body => "abc")
      response = ""
      EM.run {
        http = EventMachine::HttpRequest.new('http://www.example.com/').get
        http.stream { |chunk| response = chunk; EM.stop  }
      }
      expect(response).to eq("abc")
    end

    it "should work with responses that use chunked transfer encoding" do
      stub_request(:get, "www.example.com").to_return(:body => "abc", :headers => { 'Transfer-Encoding' => 'chunked' })
      expect(http_request(:get, "http://www.example.com").body).to eq("abc")
    end

    it "should work with optional query params" do
      stub_request(:get, "www.example.com/?x=3&a[]=b&a[]=c").to_return(:body => "abc")
      expect(http_request(:get, "http://www.example.com/?x=3", :query => {"a" => ["b", "c"]}).body).to eq("abc")
    end

    it "should work with optional query params declared as string" do
      stub_request(:get, "www.example.com/?x=3&a[]=b&a[]=c").to_return(:body => "abc")
      expect(http_request(:get, "http://www.example.com/?x=3", :query => "a[]=b&a[]=c").body).to eq("abc")
    end

    it "should work when the body is passed as a Hash" do
      stub_request(:post, "www.example.com").with(:body => {:a => "1", :b => "2"}).to_return(:body => "ok")
      expect(http_request(:post, "http://www.example.com", :body => {:a => "1", :b => "2"}).body).to eq("ok")
    end

    if defined?(EventMachine::HttpConnection)
      it "should work when a file is passed as body" do
        stub_request(:post, "www.example.com").with(:body => File.read(__FILE__)).to_return(:body => "ok")
        expect(http_request(:post, "http://www.example.com", :file => __FILE__).body).to eq("ok")
      end
    end

    it "should work with UTF-8 strings" do
      body = "Привет, Мир!"
      stub_request(:post, "www.example.com").to_return(:body => body)
      expect(http_request(:post, "http://www.example.com").body.bytesize).to eq(body.bytesize)
    end

    it "should work with multiple requests to the same connection" do
      stub_request(:get, "www.example.com/foo").to_return(:body => "bar")
      stub_request(:get, "www.example.com/baz").to_return(:body => "wombat")
      err1  = nil
      err2  = nil
      body1 = nil
      body2 = nil
      i = 0

      EM.run do
        conn = EM::HttpRequest.new("http://www.example.com")
        conn.get(:path => "/foo").callback do |resp|
          body1 = resp.response
          i += 1; EM.stop if i == 2
        end.errback do |resp|
          err1  = resp.error
          i += 1; EM.stop if i == 2
        end

        conn.get(:path => "/baz").callback do |resp|
          body2 = resp.response
          i += 1; EM.stop if i == 2
        end.errback do |resp|
          err2  = resp.error
          i += 1; EM.stop if i == 2
        end
      end

      expect(err1).to be(nil)
      expect(err2).to be(nil)
      expect(body1).to eq("bar")
      expect(body2).to eq("wombat")
    end

    it "should work with multiple requests to the same connection when the first request times out" do
      stub_request(:get, "www.example.com/foo").to_timeout.then.to_return(:status => 200, :body => "wombat")
      err  = nil
      body = nil

      EM.run do
        conn = EM::HttpRequest.new("http://www.example.com")
        conn.get(:path => "/foo").callback do |resp|
          err = :success_from_timeout
          EM.stop
        end.errback do |resp|
          conn.get(:path => "/foo").callback do |resp|
            expect(resp.response_header.status).to eq(200)
            body = resp.response
            EM.stop
          end.errback do |resp|
            err = resp.error
            EM.stop
          end
        end
      end

      expect(err).to be(nil)
      expect(body).to eq("wombat")
    end

    describe "mocking EM::HttpClient API" do
      let(:uri) { "http://www.example.com/" }

      before do
        stub_request(:get, uri)
        WebMock::HttpLibAdapters::EmHttpRequestAdapter.enable!
      end

      def client(uri, options = {})
        client = nil
        EM.run do
          client = EventMachine::HttpRequest.new(uri).get(options)
          client.callback { EM.stop }
          client.errback { failed }
        end
        client
      end

      subject { client(uri) }

      it 'should support #uri' do
        expect(subject.uri).to eq(Addressable::URI.parse(uri))
      end

      it 'should support #last_effective_url' do
        expect(subject.last_effective_url).to eq(Addressable::URI.parse(uri))
      end

      context "with a query" do
        let(:uri) { "http://www.example.com/?a=1&b=2" }
        subject { client("http://www.example.com/?a=1", :query => { 'b' => 2 }) }

        it "#request_signature doesn't mutate the original uri" do
          expect(subject.uri).to eq(Addressable::URI.parse("http://www.example.com/?a=1"))
          signature = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.first
          expect(signature.uri).to eq(Addressable::URI.parse(uri))
        end
      end

      describe 'get_response_cookie' do

        before(:each) do
          stub_request(:get, "http://example.org/").
          to_return(
            :status => 200,
            :body => "",
            :headers => { 'Set-Cookie' => cookie_string }
          )
        end

        describe 'success' do

          context 'with only one cookie' do

            let(:cookie_name) { 'name_of_the_cookie' }
            let(:cookie_value) { 'value_of_the_cookie' }
            let(:cookie_string) { "#{cookie_name}=#{cookie_value}" }

            it 'successfully gets the cookie' do
              EM.run {
                http = EventMachine::HttpRequest.new('http://example.org').get

                http.errback { fail(http.error) }
                http.callback {
                  expect(http.get_response_cookie(cookie_name)).to eq(cookie_value)
                  EM.stop
                }
              }
            end
          end

          context 'with several cookies' do

            let(:cookie_name) { 'name_of_the_cookie' }
            let(:cookie_value) { 'value_of_the_cookie' }
            let(:cookie_2_name) { 'name_of_the_2nd_cookie' }
            let(:cookie_2_value) { 'value_of_the_2nd_cookie' }
            let(:cookie_string) { %W(#{cookie_name}=#{cookie_value} #{cookie_2_name}=#{cookie_2_value}) }

            it 'successfully gets both cookies' do
              EM.run {
                http = EventMachine::HttpRequest.new('http://example.org').get

                http.errback { fail(http.error) }
                http.callback {
                  expect(http.get_response_cookie(cookie_name)).to eq(cookie_value)
                  expect(http.get_response_cookie(cookie_2_name)).to eq(cookie_2_value)
                  EM.stop
                }
              }
            end
          end
        end

        describe 'failure' do

          let(:cookie_string) { 'a=b' }

          it 'returns nil when no cookie is found' do
            EM.run {
                http = EventMachine::HttpRequest.new('http://example.org').get

                http.errback { fail(http.error) }
                http.callback {
                  expect(http.get_response_cookie('not_found_cookie')).to eq(nil)
                  EM.stop
                }
              }
          end
        end
      end
    end

  end
end
