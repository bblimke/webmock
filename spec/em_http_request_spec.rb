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
    
    it "should work with optional query params"

  end
end
