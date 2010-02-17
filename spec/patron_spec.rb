require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'


unless RUBY_PLATFORM =~ /java/
  require 'patron'
  require 'patron_spec_helper'
  
  describe "Webmock with Patron" do
    include PatronSpecHelper

    it_should_behave_like "WebMock"

    it "should support other patron methods and blocks or streams maybe"

  end
end
