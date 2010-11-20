require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'typhoeus_hydra_spec_helper'

  describe "Webmock with Typhoeus::Hydra" do
    include TyphoeusHydraSpecHelper

    it_should_behave_like "WebMock"
  end
end
