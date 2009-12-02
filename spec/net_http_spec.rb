require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'

def http_request(method, uri, options = {})
  begin
    uri = URI.parse(uri)
  rescue
    uri = Addressable::URI.heuristic_parse(uri)
  end
  response = nil
  clazz = Net::HTTP.const_get("#{method.to_s.capitalize}")
  req = clazz.new("#{uri.path}#{uri.query ? '?' : ''}#{uri.query}", options[:headers])
  
  req.basic_auth uri.user, uri.password if uri.user
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == "https"
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  response = http.start {|http|
    http.request(req, options[:body])
  }
  OpenStruct.new({
    :body => response.body,
    :headers => response,
    :status => response.code })
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


describe "Webmock with Net:HTTP" do
  
  it_should_behave_like "WebMock"
  
  it "should work with block provided" do
    stub_http_request(:get, "www.google.com").to_return(:body => "abc"*100000)
    Net::HTTP.start("www.google.com") { |query| query.get("/") }.body.should == "abc"*100000
  end
end
