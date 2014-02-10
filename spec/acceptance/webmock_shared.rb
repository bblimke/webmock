require 'spec_helper'
require 'acceptance/shared/enabling_and_disabling_webmock'
require 'acceptance/shared/returning_declared_responses'
require 'acceptance/shared/callbacks'
require 'acceptance/shared/request_expectations'
require 'acceptance/shared/stubbing_requests'
require 'acceptance/shared/allowing_and_disabling_net_connect'
require 'acceptance/shared/precedence_of_stubs'
require 'acceptance/shared/complex_cross_concern_behaviors'

unless defined? SAMPLE_HEADERS
  SAMPLE_HEADERS = { "Content-Length" => "8888", "Accept" => "application/json" }
  ESCAPED_PARAMS = "x=ab%20c&z=%27Stop%21%27%20said%20Fred%20m"
  NOT_ESCAPED_PARAMS = "z='Stop!' said Fred m&x=ab c"
end

shared_examples "with WebMock" do |*adapter_info|
  describe "with WebMock" do
    let(:webmock_server_url) {"http://#{WebMockServer.instance.host_with_port}/"}
    before(:each) do
      WebMock.disable_net_connect!
      WebMock.reset!
    end

    it "preserves content-type header when proxying to a rack app" do
      stub_request(:any, //).to_rack(lambda {|req| [200, {}, ["OK"]] })

      url = "https://google.com/hi/there"
      headers = {
        "Accept"       => "application/json",
        "Content-Type" => "application/json"
      }

      http_request(:get, url, :headers => headers)
      WebMock.should have_requested(:get, url).with(:headers => headers)
    end

    include_context "allowing and disabling net connect", *adapter_info

    include_context "stubbing requests", *adapter_info

    include_context "declared responses", *adapter_info

    include_context "precedence of stubs", *adapter_info

    include_context "request expectations", *adapter_info

    include_context "callbacks", *adapter_info

    include_context "enabled and disabled webmock", *adapter_info

    include_context "complex cross-concern behaviors", *adapter_info
  end
end
