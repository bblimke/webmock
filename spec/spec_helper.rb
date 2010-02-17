require 'rubygems'
require 'httpclient'
require 'patron' unless RUBY_PLATFORM =~ /java/

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'spec'
require 'spec/autorun'

require 'webmock/rspec'

require 'json'

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
    :response_body => "<title>example</title>" }
  setup_expectations_for_real_request(defaults.merge(options))
end

def client_specific_request_string(string)
  method = string.gsub(/.*Unregistered request: ([^ ]+).+/, '\1')
  has_body = string.include?(" with body")
  default_headers = default_client_request_headers(method, has_body)
  if default_headers
   default_headers_string = WebMock::Util::Headers.normalize_headers(default_headers).inspect.gsub("\"","'")
   default_headers_string.gsub!(/[{}]/, "")
   if string.include?(" with headers")
      current_headers = JSON.parse(string.gsub(/.*with headers (\{[^}]+\}).*/, '\1').gsub("=>",":").gsub("'","\""))
      default_headers = WebMock::Util::Headers.normalize_headers(default_headers)
      default_headers.reject! {|k,v| current_headers.has_key?(k) }
      default_headers_string = default_headers.inspect.gsub("\"","'").gsub!(/[{}]/, "")
      string.gsub!(/(.*)(with headers \{[^}]*)(\}.*)/, '\1\2' + ", #{default_headers_string}}") if !default_headers_string.empty?
      string
    else
      headers_string = 
      " with headers #{WebMock::Util::Headers.normalize_headers(default_headers).inspect.gsub("\"","'")}"
      string << headers_string
      end
  end
  string
end



