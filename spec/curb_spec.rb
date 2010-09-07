require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'

unless RUBY_PLATFORM =~ /java/
  require 'curb_spec_helper'
  require 'tmpdir'
  require 'fileutils'

  describe "Webmock with Curb" do
    describe "using dynamic #http for requests" do
      include CurbSpecHelper
      include CurbSpecHelper::DynamicHttp

      it_should_behave_like "WebMock"
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
