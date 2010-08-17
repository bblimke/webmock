require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'

unless RUBY_PLATFORM =~ /java/
  require 'curb_spec_helper'
  require 'tmpdir'
  require 'fileutils'

  describe "Webmock with Curb" do
    include CurbSpecHelper

    it_should_behave_like "WebMock"
  end
end
