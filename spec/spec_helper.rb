require 'rubygems'
require 'httpclient'
$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'spec'
require 'spec/autorun'

require 'webmock/rspec'

include WebMock

def fail()
  raise_error(Spec::Expectations::ExpectationNotMetError)
end

def fail_with(message)
  raise_error(Spec::Expectations::ExpectationNotMetError, message)
end

class Proc
  def should_pass
    lambda { self.call }.should_not raise_error
  end
end

def setup_expectations_for_real_example_com_request(options = {})
  defaults = { :host => "www.example.com", :port => 80, :method => "GET",
    :path => "/",
    :response_code => 200, :response_message => "OK",
    :response_body => "<title>Google fake response</title>" }
  setup_expectations_for_real_request(defaults.merge(options))
end

