require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'
require 'net_http_spec_helper'

include NetHTTPSpecHelper

describe "Webmock with Net:HTTP" do

  it_should_behave_like "WebMock"

  it "should work with block provided" do
    stub_http_request(:get, "www.google.com").to_return(:body => "abc"*100000)
    Net::HTTP.start("www.google.com") { |query| query.get("/") }.body.should == "abc"*100000
  end
end
