require 'rubygems'
require 'httpclient'
unless RUBY_PLATFORM =~ /java/
  require 'curb'
  require 'patron'
  require 'em-http'
  require 'typhoeus'
end
if RUBY_PLATFORM =~ /java/
  require 'manticore'
end

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'rspec'

require 'webmock/rspec'

require 'support/network_connection'
require 'support/webmock_server'
require 'support/my_rack_app'
require 'support/failures'

CURL_EXAMPLE_OUTPUT_PATH = File.expand_path('../support/example_curl_output.txt', __FILE__)

RSpec.configure do |config|
  no_network_connection = ENV["NO_CONNECTION"] || ! NetworkConnection.is_network_available?
  if no_network_connection
    warn("No network connectivity. Only examples which do not make real network connections will run.")
    config.filter_run_excluding net_connect: true
  end

  config.filter_run_excluding without_webmock: true

  config.before(:suite) do
    WebMockServer.instance.start unless WebMockServer.instance.started
  end

  config.after(:suite) do
    WebMockServer.instance.stop
  end

  config.filter_run focus: true
  config.run_all_when_everything_filtered = true

  config.include Failures
end

