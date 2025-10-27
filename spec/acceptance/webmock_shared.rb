require 'spec_helper'
require 'acceptance/shared/enabling_and_disabling_webmock'
require 'acceptance/shared/returning_declared_responses'
require 'acceptance/shared/callbacks'
require 'acceptance/shared/request_expectations'
require 'acceptance/shared/stubbing_requests'
require 'acceptance/shared/allowing_and_disabling_net_connect'
require 'acceptance/shared/precedence_of_stubs'
require 'acceptance/shared/complex_cross_concern_behaviors'

unless defined? SAMPLE_REQUEST_HEADERS
  SAMPLE_REQUEST_HEADERS = { "Accept" => "application/json" }
  SAMPLE_RESPONSE_HEADERS = { "Content-Type" => "application/json", "Content-Length" => "8888" }
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

    around(:each, net_connect: true) do |ex|
      ex.run_with_retry retry: 2, exceptions_to_retry: [
        client_timeout_exception_class,
        connection_refused_exception_class,
        connection_error_class
      ].compact
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
