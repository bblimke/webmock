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

          urls.should eq([http_url, https_url])
        end

        it 'invokes the after_request hook with both requests' do
          urls = []
          WebMock.after_request { |req, res| urls << req.uri.to_s }

          make_request

          urls.should eq([http_url, https_url])
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
              WebMock.should have_requested(:get, "www.example.com").with(:body => 'bar')
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
              http.response.should be == 'bar'
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

            yielded_response_body.should eq("hello world")
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
            lambda {
              EM.run do
                fiber = Fiber.new do
                  http = EM::HttpRequest.new("http://www.testserver.com").post :body => "foo=bar&baz=bang", :timeout => 60
                  EM.stop
                end
                fiber.resume
              end
            }.should_not raise_error
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
      response.should == "abc"
    end

    it "should work with responses that use chunked transfer encoding" do
      stub_request(:get, "www.example.com").to_return(:body => "abc", :headers => { 'Transfer-Encoding' => 'chunked' })
      http_request(:get, "http://www.example.com").body.should == "abc"
    end

    it "should work with optional query params" do
      stub_request(:get, "www.example.com/?x=3&a[]=b&a[]=c").to_return(:body => "abc")
      http_request(:get, "http://www.example.com/?x=3", :query => {"a" => ["b", "c"]}).body.should == "abc"
    end

    it "should work with optional query params declared as string" do
      stub_request(:get, "www.example.com/?x=3&a[]=b&a[]=c").to_return(:body => "abc")
      http_request(:get, "http://www.example.com/?x=3", :query => "a[]=b&a[]=c").body.should == "abc"
    end

    it "should work when the body is passed as a Hash" do
      stub_request(:post, "www.example.com").with(:body => {:a => "1", :b => "2"}).to_return(:body => "ok")
      http_request(:post, "http://www.example.com", :body => {:a => "1", :b => "2"}).body.should == "ok"
    end

    it "should work with UTF-8 strings" do
      body = "Привет, Мир!"
      stub_request(:post, "www.example.com").to_return(:body => body)
      http_request(:post, "http://www.example.com").body.bytesize.should == body.bytesize
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
        subject.uri.should == Addressable::URI.parse(uri)
      end

      it 'should support #last_effective_url' do
        subject.last_effective_url.should == Addressable::URI.parse(uri)
      end

      context "with a query" do
        let(:uri) { "http://www.example.com/?a=1&b=2" }
        subject { client("http://www.example.com/?a=1", :query => { 'b' => 2 }) }

        it "#request_signature doesn't mutate the original uri" do
          subject.uri.should == Addressable::URI.parse("http://www.example.com/?a=1")
          signature = WebMock::RequestRegistry.instance.requested_signatures.hash.keys.first
          signature.uri.should == Addressable::URI.parse(uri)
        end
      end
    end

  end
end
