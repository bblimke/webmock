require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_spec'
require 'ostruct'

require 'httpclient'

describe "Webmock with HTTPClient" do

  def http_request(method, uri, options = {})
    uri = Addressable::URI.heuristic_parse(uri)
    c = HTTPClient.new
    c.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    c.set_basic_auth(nil, uri.user, uri.password) if uri.user
    response = c.request(method, "#{uri.omit(:userinfo, :query).normalize.to_s}",
      uri.query_values, options[:body], options[:headers] || {})
    OpenStruct.new({
      :body => response.content,
      :headers => Hash[response.header.all],
      :status => response.code.to_s })
  end

  def setup_expectations_for_real_request(options = {})
    socket = mock("TCPSocket")
    TCPSocket.should_receive(:new).
      with(options[:host], options[:port]).at_least(:once).and_return(socket)

    socket.stub!(:closed?).and_return(false)
    socket.stub!(:close).and_return(true)

    request_parts = ["#{options[:method]} #{options[:path]} HTTP/1.1", "Host: #{options[:host]}"]

    if options[:port] == 443
      OpenSSL::SSL::SSLSocket.should_receive(:new).
        with(socket, instance_of(OpenSSL::SSL::SSLContext)).
        at_least(:once).and_return(socket = mock("SSLSocket"))
      socket.should_receive(:connect).at_least(:once).with()
      socket.should_receive(:peer_cert).and_return(mock('peer cert', :extensions => []))
      socket.should_receive(:write).with(/#{request_parts[0]}.*#{request_parts[1]}.*/m).and_return(100)
    else
      socket.should_receive(:<<).with(/#{request_parts[0]}.*#{request_parts[1]}.*/m).and_return(100)
    end

    socket.stub!(:sync=).with(true)

    socket.should_receive(:gets).with("\n").once.and_return("HTTP/1.1 #{options[:response_code]} #{options[:response_message]}\nContent-Length: #{options[:response_body].length}\n\n#{options[:response_body]}")

    socket.stub!(:eof?).and_return(true)
    socket.stub!(:close).and_return(true)

    socket.should_receive(:readpartial).any_number_of_times.and_raise(EOFError)
  end


  it_should_behave_like "WebMock"

end
