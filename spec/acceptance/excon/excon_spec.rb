require 'spec_helper'
require 'acceptance/webmock_shared'
require 'acceptance/excon/excon_spec_helper'

describe "Excon" do
  include ExconSpecHelper
  include_context "with WebMock", :no_status_message, :no_url_auth

  it 'should allow Excon requests to use query hash paramters' do
    stub_request(:get, "http://example.com/resource/?a=1&b=2").to_return(:body => "abc")
    Excon.get('http://example.com', :path => "resource/", :query => {:a => 1, :b => 2}).body.should == "abc"
  end

  let(:file) { File.new(__FILE__) }
  let(:file_contents) { File.new(__FILE__).read }

  it 'handles file uploads correctly' do
    stub_request(:put, "http://example.com/upload").with(:body => file_contents)

    yielded_request_body = nil
    WebMock.after_request do |req, res|
      yielded_request_body = req.body
    end

    Excon.put("http://example.com", :path => "upload", :body => file)

    yielded_request_body.should eq(file_contents)
  end
end

