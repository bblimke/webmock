require 'spec_helper'
require 'acceptance/shared/enabling_and_disabling_webmock'
require 'acceptance/shared/returning_declared_responses'
require 'acceptance/shared/callbacks'
require 'acceptance/shared/request_expectations'
require 'acceptance/shared/stubbing_requests'
require 'acceptance/shared/allowing_and_disabling_net_connect'
require 'acceptance/shared/precedence_of_stubs'

unless defined? SAMPLE_HEADERS
  SAMPLE_HEADERS = { "Content-Length" => "8888", "Accept" => "application/json" }
  ESCAPED_PARAMS = "x=ab%20c&z=%27Stop%21%27%20said%20Fred"
  NOT_ESCAPED_PARAMS = "z='Stop!' said Fred&x=ab c"
end

shared_examples_for "WebMock" do
  let(:webmock_server_url) {"http://#{WebMockServer.instance.host_with_port}/"}
  before(:each) do
    WebMock.disable_net_connect!
    WebMock.reset!
  end

  it_should_behave_like "allowing and disabling net connect"

  it_should_behave_like "stubbing requests"

  it_should_behave_like "returning declared responses"

  it_should_behave_like "precedence of stubs"

  it_should_behave_like "verifying request expectations"

  it_should_behave_like "callbacks"

  it_should_behave_like "enabled and disabled webmock"
end
