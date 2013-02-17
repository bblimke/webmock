require 'spec_helper'
require 'acceptance/webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'acceptance/typhoeus/typhoeus_hydra_spec_helper'

  describe "Typhoeus::Hydra" do
    include TyphoeusHydraSpecHelper
    let(:hydra) { Typhoeus::Hydra.new }

    before do
      Typhoeus::Expectation.clear
    end

    include_context "with WebMock"

    describe "Typhoeus::Hydra features" do
      before(:each) do
        WebMock.disable_net_connect!
        WebMock.reset!
      end

      describe "when params are used" do
        it "should take into account params for POST request" do
          stub_request(:post, "www.example.com/?hello=world").with(:params => {:hello => 'world'})
          request = Typhoeus::Request.new("http://www.example.com", :method => :post, :params => {:hello => 'world'})
          hydra.queue(request)
          hydra.run
        end

        it "should take into account params for GET request" do
          stub_request(:get, "http://www.example.com/?hello=world").to_return({})
          request = Typhoeus::Request.new("http://www.example.com/?hello=world", :method => :get)
          hydra.queue(request)
          hydra.run
        end
      end

      describe "timeouts" do
        it "should support native typhoeus timeouts" do
          stub_request(:any, "example.com").to_timeout

          request = Typhoeus::Request.new("http://example.com", :method => :get)
          hydra.queue(request)
          hydra.run

          request.response.should be_timed_out
        end
      end

      describe "callbacks" do
        before(:each) do
          @request = Typhoeus::Request.new("http://example.com")
        end

        it "should call on_complete with 2xx response" do
          body = "on_success fired"
          stub_request(:any, "example.com").to_return(:body => body)

          test = nil
          Typhoeus.on_complete do |c|
            test = c.body
          end
          hydra.queue @request
          hydra.run
          test.should == body
        end

        it "should call on_complete with 5xx response" do
          response_code = 599
          stub_request(:any, "example.com").to_return(:status => [response_code, "Server On Fire"])

          test = nil
          Typhoeus.on_complete do |c|
            test = c.code
          end
          hydra.queue @request
          hydra.run
          test.should == response_code
        end
      end
    end
  end
end
