require 'webmock'
require 'rspec'
require 'webmock/adapters/rspec/request_pattern_matcher'
require 'webmock/adapters/rspec/webmock_matcher'
require 'webmock/adapters/rspec/matchers'

Rspec.configure { |config|

  config.include WebMock::Matchers

  config.before :each do
    WebMock.reset_webmock
  end
}

module WebMock
  def assertion_failure(message)
    raise Rspec::Expectations::ExpectationNotMetError.new(message)
  end
end