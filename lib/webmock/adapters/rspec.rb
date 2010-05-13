require 'webmock'

# RSpec 1.x and 2.x compatibility
begin
  require 'rspec'
  RSPEC_NAMESPACE = RSPEC_CONFIGURER = Rspec
rescue LoadError
  require 'spec'
  RSPEC_NAMESPACE = Spec
  RSPEC_CONFIGURER = Spec::Runner
end

require 'webmock/adapters/rspec/request_pattern_matcher'
require 'webmock/adapters/rspec/webmock_matcher'
require 'webmock/adapters/rspec/matchers'
  
RSPEC_CONFIGURER.configure { |config|

  config.include WebMock::Matchers

  config.before :each do
    WebMock.reset_webmock
  end
}

module WebMock
  def assertion_failure(message)
    raise RSPEC_NAMESPACE::Expectations::ExpectationNotMetError.new(message)
  end
end