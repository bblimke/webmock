require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'
require 'net_http_spec_helper'

include NetHTTPSpecHelper

describe "Webmock with Net:HTTP" do

  it_should_behave_like "WebMock"

  it "should work with block provided" do
    stub_http_request(:get, "www.example.com").to_return(:body => "abc"*100000)
    Net::HTTP.start("www.example.com") { |query| query.get("/") }.body.should == "abc"*100000
  end
  
  it "should yield block on response" do
    stub_http_request(:get, "www.example.com").to_return(:body => "abc")
    response_body = ""
    http_request(:get, "http://www.example.com/") do |response|
      response_body = response.body
    end
    response_body.should == "abc"
  end

  it "should handle Net::HTTP::Post#body" do
    stub_http_request(:post, "www.example.com").with(:body => "my_params").to_return(:body => "abc")
    req = Net::HTTP::Post.new("/")
    req.body = "my_params"
    Net::HTTP.start("www.example.com") { |http| http.request(req)}.body.should == "abc"
  end
end
