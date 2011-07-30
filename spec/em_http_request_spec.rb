require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_shared'
require 'ostruct'

unless RUBY_PLATFORM =~ /java/
  require 'em_http_request_spec_helper'

  describe "Webmock with EM::HttpRequest" do
    include EMHttpRequestSpecHelper

    it_should_behave_like "WebMock"

    it "should work with request middleware" do
      stub_http_request(:get, "www.example.com").with(:body => 'bar')

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

    it "should work with response middleware" do
      stub_http_request(:get, "www.example.com").to_return(:body => 'foo')

      middleware = Class.new do
        def response(resp)
          resp.response = 'bar'
        end
      end

      EM.run do
        conn = EventMachine::HttpRequest.new('http://www.example.com/')

        conn.use middleware

        http = conn.get

        http.callback do
          http.response.should be == 'bar'
          EM.stop
        end
      end
    end

    it "should work with streaming" do
      stub_http_request(:get, "www.example.com").to_return(:body => "abc")
      response = ""
      EM.run {
        http = EventMachine::HttpRequest.new('http://www.example.com/').get
        http.stream { |chunk| response = chunk; EM.stop  }
      }
      response.should == "abc"
    end

    it "should work with responses that use chunked transfer encoding" do
      stub_http_request(:get, "www.example.com").to_return(:body => "abc", :headers => { 'Transfer-Encoding' => 'chunked' })
      http_request(:get, "http://www.example.com").body.should == "abc"
    end

    it "should work with optional query params" do
      stub_http_request(:get, "www.example.com/?x=3&a[]=b&a[]=c").to_return(:body => "abc")
      http_request(:get, "http://www.example.com/?x=3", :query => {"a" => ["b", "c"]}).body.should == "abc"
    end

    it "should work with optional query params declared as string" do
      stub_http_request(:get, "www.example.com/?x=3&a[]=b&a[]=c").to_return(:body => "abc")
      http_request(:get, "http://www.example.com/?x=3", :query => "a[]=b&a[]=c").body.should == "abc"
    end

    # not pretty, but it works
    describe "with synchrony" do
      let(:webmock_em_http) { File.expand_path(File.join(File.dirname(__FILE__), "../lib/webmock/http_lib_adapters/em_http_request.rb")) }

      before(:each) do
        # need to reload the webmock em-http adapter after we require synchrony
        EM::WebMockHttpClient.deactivate!
        $".delete webmock_em_http
        require 'em-synchrony'
        require 'em-synchrony/em-http'
        require webmock_em_http
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
        EM::WebMockHttpClient.deactivate!
        $".reject! {|path| path.include? "em-http-request"}
        $".delete webmock_em_http
        require 'em-http-request'
        require webmock_em_http
      end
    end

    describe "mocking EM::HttpClient API" do
      before { stub_http_request(:get, "www.example.com/") }
      subject do
        client = nil
        EM.run do
          client = EventMachine::HttpRequest.new('http://www.example.com/').get
          client.callback { EM.stop }
          client.errback { failed }
        end
        client
      end

      it 'should support #uri' do
        subject.uri.should == Addressable::URI.parse('http://www.example.com/')
      end

      it 'should support #last_effective_url' do
        subject.last_effective_url.should == Addressable::URI.parse('http://www.example.com/')
      end
    end

  end
end
