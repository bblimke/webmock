require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'

require 'httpclient'
require 'httpclient_spec_helper'

describe "Webmock with HTTPClient" do
  include HTTPClientSpecHelper

  before(:each) do
    HTTPClientSpecHelper.async_mode = false
  end

  it_should_behave_like "WebMock"

  it "should yield block on response if block provided" do
    stub_http_request(:get, "www.example.com").to_return(:body => "abc")
    response_body = ""
    http_request(:get, "http://www.example.com/") do |body|
      response_body = body
    end
    response_body.should == "abc"
  end

  describe "async requests" do

    before(:each) do
      HTTPClientSpecHelper.async_mode = true
    end

    it_should_behave_like "WebMock"

  end

end
