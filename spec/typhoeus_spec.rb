require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'typhoeus_spec_helper'

  describe "Webmock with Typhoeus" do
    include TyphoeusSpecHelper

    it_should_behave_like "WebMock"

  end

end
