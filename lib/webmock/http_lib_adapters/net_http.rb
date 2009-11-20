require 'net/http'
require 'net/https'
require 'stringio'


class StubSocket #:nodoc:

  def initialize(*args)
  end

  def closed?
    @closed ||= true
  end

  def readuntil(*args)
  end

end

module StubResponse
  def read_body(*args, &block)
    yield @body if block_given?
    @body
  end
end

module Net  #:nodoc: all

  class BufferedIO
    def initialize_with_webmock(io, debug_output = nil)
      @read_timeout = 60
      @rbuf = ''
      @debug_output = debug_output

      @io = case io
      when Socket, OpenSSL::SSL::SSLSocket, IO
        io
      when String
        if !io.include?("\0") && File.exists?(io) && !File.directory?(io)
          File.open(io, "r")
        else
          StringIO.new(io)
        end
      end
      raise "Unable to create local socket" unless @io
    end
    alias_method :initialize_without_webmock, :initialize
    alias_method :initialize, :initialize_with_webmock
  end

  class HTTP
    class << self
      def socket_type_with_webmock
        StubSocket
      end
      alias_method :socket_type_without_webmock, :socket_type
      alias_method :socket_type, :socket_type_with_webmock
    end

    def request_with_webmock(request, body = nil, &block)
      protocol = use_ssl? ? "https" : "http"

      path = request.path
      path = URI.parse(request.path).request_uri if request.path =~ /^http/

      if request["authorization"] =~ /^Basic /
        userinfo = WebMock::Utility.decode_userinfo_from_header(request["authorization"])
        userinfo = WebMock::Utility.encode_unsafe_chars_in_userinfo(userinfo) + "@"
      else
        userinfo = ""
      end

      uri = "#{protocol}://#{userinfo}#{self.address}:#{self.port}#{path}"
      method = request.method.downcase.to_sym

      headers = Hash[*request.to_hash.map {|k,v| [k, v.flatten]}.flatten]
      headers.reject! {|k,v| k =~ /[Aa]ccept/ && v = '*/*'}

      request_profile = WebMock::RequestProfile.new(method, uri, body, headers)

      if WebMock.registered_request?(request_profile)
        @socket = Net::HTTP.socket_type.new
        webmock_response = WebMock.response_for_request(request_profile)
        build_net_http_response(webmock_response, &block)
      elsif WebMock.net_connect_allowed?
        WebMock::RequestRegistry.instance.requested.put(request_profile)
        connect_without_webmock
        request_without_webmock(request, body, &block)
      else
        uri = WebMock::Utility.strip_default_port_from_uri(uri)
        message = "Real HTTP connections are disabled. Unregistered request: #{request.method} #{uri}"
        message << " with body '#{body}'" if body
        message << " with headers #{WebMock::Utility.normalize_headers(headers).inspect.gsub("\"","'")}" if 
headers && !headers.empty?
        raise WebMock::NetConnectNotAllowedError, message
      end
    end
    alias_method :request_without_webmock, :request
    alias_method :request, :request_with_webmock


    def connect_with_webmock
      unless @@alredy_checked_for_net_http_replacement_libs ||= false
        WebMock::Utility.puts_warning_for_net_http_replacement_libs_if_needed
        @@alredy_checked_for_net_http_replacement_libs = true
      end
      nil
    end
    alias_method :connect_without_webmock, :connect
    alias_method :connect, :connect_with_webmock

    def build_net_http_response(webmock_response, &block)
      response = Net::HTTPResponse.send(:response_class, webmock_response.status.to_s).new("1.0", webmock_response.status.to_s, "")
      response.instance_variable_set(:@body, webmock_response.body)
      webmock_response.headers.to_a.each { |name, value| response[name] = value }

      response.instance_variable_set(:@read, true)

      response.extend StubResponse

      webmock_response.raise_error_if_any

      yield response if block_given?

      response
    end
  end

end
