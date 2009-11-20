$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'webmock'
require 'spec'
require 'spec/autorun'

include WebMock

def fail()
  raise_error(Spec::Expectations::ExpectationNotMetError)
end

def fail_with(message)
  raise_error(Spec::Expectations::ExpectationNotMetError,message)
end

class Proc
  def should_pass
    lambda { self.call }.should_not raise_error
  end
end

# Sets several expectations that a real HTTP request makes it
# past WebMock to the socket layer. You can use this when you need to check
# that a request isn't handled by WebMock
#This solution is copied from FakeWeb project
def setup_expectations_for_real_request(options = {})
  # Socket handling
  if options[:port] == 443
    socket = mock("SSLSocket")
    OpenSSL::SSL::SSLSocket.should_receive(:===).with(socket).at_least(:once).and_return(true)
    OpenSSL::SSL::SSLSocket.should_receive(:new).with(socket, instance_of(OpenSSL::SSL::SSLContext)).at_least(:once).and_return(socket)
    socket.stub!(:sync_close=).and_return(true)
    socket.should_receive(:connect).at_least(:once).with()
  else
    socket = mock("TCPSocket")
    Socket.should_receive(:===).with(socket).at_least(:once).and_return(true)
  end

  TCPSocket.should_receive(:open).with(options[:host], options[:port]).at_least(:once).and_return(socket)
  socket.stub!(:closed?).and_return(false)
  socket.stub!(:close).and_return(true)

  # Request/response handling
  request_parts = ["#{options[:method]} #{options[:path]} HTTP/1.1", "Host: #{options[:host]}"]
  socket.should_receive(:write).with(/#{request_parts[0]}.*#{request_parts[1]}.*/m).and_return(100)

  socket.should_receive(:sysread).once.and_return("HTTP/1.1 #{options[:response_code]} #{options[:response_message]}\nContent-Length: #{options[:response_body].length}\n\n#{options[:response_body]}")
  socket.should_receive(:sysread).any_number_of_times.and_raise(EOFError)
end

def setup_expectations_for_real_google_request(options = {})
  defaults = { :host => "www.google.com", :port => 80, :method => "GET",
    :path => "/",
    :response_code => 200, :response_message => "OK",
    :response_body => "<title>Google fake response</title>" }
  setup_expectations_for_real_request(defaults.merge(options))
end
