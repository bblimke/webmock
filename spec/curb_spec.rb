require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'

unless RUBY_PLATFORM =~ /java/
  require 'curb_spec_helper'

  describe "Curb", :shared => true do
    include CurbSpecHelper
    
    it_should_behave_like "WebMock"

    describe "when doing PUTs" do
      it "should stub them" do
        stub_http_request(:put, "www.example.com").with(:body => "put_data")
        http_request(:put, "http://www.example.com", 
          :body => "put_data").status.should == "200"
      end
    end
  end

  describe "Webmock with Curb" do
    describe "using dynamic #http for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::DynamicHttp

      it "should work with uppercase arguments" do
        stub_request(:get, "www.example.com").to_return(:body => "abc")

        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.http(:GET)
        c.body_str.should == "abc"
      end
    end

    describe "using named #http_* methods for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::NamedHttp
    end

    describe "using named #perform for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::Perform
    end
  end
end
