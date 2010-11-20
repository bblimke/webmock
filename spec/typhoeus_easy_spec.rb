require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'typhoeus_easy_spec_helper'

  describe "Webmock with Typhoeus::Easy" do
    include TyphoeusEasySpecHelper

    it_should_behave_like "WebMock"

    describe "Typhoeus::Easy features" do
      before(:each) do
        WebMock.disable_net_connect!
        WebMock.reset!
      end

      describe "callbacks" do
        before(:each) do
          @easy = Typhoeus::Easy.new
          @easy.url = "http://example.com"
        end

        it "should call on_success with 2xx response" do
          body = "on_success fired"
          stub_request(:any, "example.com").to_return(:body => body)

          test = nil
          @easy.on_success do |c|
            test = c.response_body
          end
          @easy.perform
          test.should == body
        end

        it "should call on_failure with 5xx response" do
          response_code = 599
          stub_request(:any, "example.com").
            to_return(:status => [response_code, "Server On Fire"])

          test = nil
          @easy.on_failure do |c|
            test = c.response_code
          end
          @easy.perform
          test.should == response_code
        end


        it "should call callbacks only success callback on success request" do
          stub_request(:any, "example.com")
          order = []
          @easy.on_success {|*args| order << :on_success }
          @easy.on_failure {|*args| order << :on_failure }
          @easy.perform

          order.should == [:on_success]
        end

        it "should call callbacks only failed callback on failed request" do
          stub_request(:any, "example.com").to_return(:status => [500, ""])
          order = []
          @easy.on_success {|*args| order << :on_success }
          @easy.on_failure {|*args| order << :on_failure }
          @easy.perform

          order.should == [:on_failure]
        end
      end
    end

  end
end
