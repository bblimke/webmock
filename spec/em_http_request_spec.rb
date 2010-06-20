require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'

unless RUBY_PLATFORM =~ /java/
  require 'em_http_request_spec_helper'

  describe "Webmock with EM::HttpRequest" do
    include EMHttpRequestSpecHelper

    it_should_behave_like "WebMock"

    it "should work with block"
    
    it "should work with streaming"
    
    it "should work with optional query params" do
      stub_http_request(:get, "www.example.com/?x=3&a[]=b&a[]=c").to_return(:body => "abc")
      http_request(:get, "http://www.example.com/?x=3", :query => {"a" => ["b", "c"]}).body.should == "abc"
    end

  end
end
