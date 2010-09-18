require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'

unless RUBY_PLATFORM =~ /java/
  require 'curb_spec_helper'

  describe "Webmock with Curb" do
    describe "using dynamic #http for requests" do
      include CurbSpecHelper
      include CurbSpecHelper::DynamicHttp

      it_should_behave_like "WebMock"

      it "should work with uppercase arguments" do
        stub_request(:get, "www.example.com").to_return(:body => "abc")

        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.http(:GET)
        c.body_str.should == "abc"
      end
    end

#    describe "using named #http_* methods for requests" do
#      include CurbSpecHelper
#      include CurbSpecHelper::NamedHttp
#
#      it_should_behave_like "WebMock"
#    end
#
#    describe "using named #perform for requests" do
#      include CurbSpecHelper
#      include CurbSpecHelper::Perform
#
#      it_should_behave_like "WebMock"
#    end
  end
end
