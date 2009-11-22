require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'

include WebMock

def http_request(method, url, options = {})
  begin
    url = URI.parse(url)
  rescue
    url = Addressable::URI.heuristic_parse(url)
  end
  response = nil
  clazz = Net::HTTP.const_get("#{method.to_s.capitalize}")
  req = clazz.new("#{url.path}#{url.query ? '?' : ''}#{url.query}", options[:headers])
  req.basic_auth url.user, url.password if url.user
  http = Net::HTTP.new(url.host, url.port)
  http.use_ssl = true if url.scheme == "https"
  response = http.start {|http|
    http.request(req, options[:body])
  }
  OpenStruct.new({
    :body => response.body,
    :headers => response,
    :status => response.code })
end

describe "Webmock with Net:HTTP" do
  
  it_should_behave_like "WebMock"
  
  it "should work with block provided" do
    stub_http_request(:get, "www.google.com").to_return(:body => "abc"*100000)
    Net::HTTP.start("www.google.com") { |query| query.get("/") }.body.should == "abc"*100000
  end
end
