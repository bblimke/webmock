require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'

require 'httpclient'
require 'httpclient_spec_helper'

describe "Webmock with HTTPClient" do
  include HTTPClientSpecHelper

  before(:each) do
    HTTPClientSpecHelper.async_mode = false
  end

  it_should_behave_like "WebMock"

  describe "async requests" do

    before(:each) do
      HTTPClientSpecHelper.async_mode = true
    end

    it_should_behave_like "WebMock"

  end

end
