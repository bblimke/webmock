require 'spec_helper'
require 'acceptance/webmock_shared'
require 'acceptance/excon/excon_spec_helper'

describe "Excon" do
  include ExconSpecHelper
  include_context "with WebMock", :no_status_message, :no_url_auth

  it 'should allow Excon requests to use query hash paramters' do
    stub_request(:get, "http://example.com/resource/?a=1&b=2").to_return(:body => "abc")
    Excon.new('http://example.com').get(:path => "resource/", :query => {:a => 1, :b => 2}).body.should == "abc"
  end

  it 'should support Excon :expects options' do
    stub_request(:get, "http://example.com/").to_return(:body => 'a')
    lambda { Excon.new('http://example.com').get(:expects => 204) }.should raise_error(Excon::Errors::OK)
  end

  context "with response_block" do
    it "should support excon response_block for real requests" do
      a = []
      WebMock.allow_net_connect!
      r = Excon.new('http://httpstat.us/200').get(:response_block => lambda {|e, remaining, total| a << e}, :chunk_size => 1)
      a.should == ["2", "0", "0", " ", "O", "K"]
      r.body.should == ""
    end

    it "should support excon response_block" do
      a = []
      stub_request(:get, "http://example.com/").to_return(:body => "abc")
      r = Excon.new('http://example.com').get(:response_block => lambda {|e, remaining, total| a << e}, :chunk_size => 1)
      a.should == ['a', 'b', 'c']
      r.body.should == ""
    end

    it "should invoke callbacks with response body even if a real request is made" do
      a = []
      WebMock.allow_net_connect!
      response = nil
      WebMock.after_request { |_, res|
        response = res
      }
      r = Excon.new('http://httpstat.us/200').get(:response_block => lambda {|e, remaining, total| a << e}, :chunk_size => 1)
      response.body.should == "200 OK"
      a.should == ["2", "0", "0", " ", "O", "K"]
      r.body.should == ""
    end
  end

  let(:file) { File.new(__FILE__) }
  let(:file_contents) { File.new(__FILE__).read }

  it 'handles file uploads correctly' do
    stub_request(:put, "http://example.com/upload").with(:body => file_contents)

    yielded_request_body = nil
    WebMock.after_request do |req, res|
      yielded_request_body = req.body
    end

    Excon.new("http://example.com").put(:path => "upload", :body => file)

    yielded_request_body.should eq(file_contents)
  end
end
