require 'webmock'
require 'spec'
require 'webmock/adapters/rspec/request_profile_matcher'
require 'webmock/adapters/rspec/webmock_matcher'
require 'webmock/adapters/rspec/matchers'

Spec::Runner.configure { |config|

  config.include WebMock::Matchers

  config.before :each do
    WebMock.reset_webmock
  end
}

module WebMock
  def assertion_failure(message)
    raise Spec::Expectations::ExpectationNotMetError.new(message)
  end
end
