require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'

require 'httpclient'
require 'httpclient_spec_helper'

include HTTPClientSpecHelper

describe "Webmock with HTTPClient" do

  it_should_behave_like "WebMock"

  describe "async requests" do

    sync_mode = false

    it_should_behave_like "WebMock"

  end

end
