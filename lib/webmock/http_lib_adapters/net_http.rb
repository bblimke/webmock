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
        StringIO.new(io)
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
      request_signature = WebMock::NetHTTPUtility.request_signature_from_request(self, request, body)

      WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

      if WebMock.registered_request?(request_signature)
        @socket = Net::HTTP.socket_type.new
        webmock_response = WebMock.response_for_request(request_signature)
        build_net_http_response(webmock_response, &block)
      elsif WebMock.net_connect_allowed?(request_signature.uri)
        connect_without_webmock
        request_without_webmock(request, nil, &block)
      else
        raise NetConnectNotAllowedError.new(request_signature)
      end
    end
    alias_method :request_without_webmock, :request
    alias_method :request, :request_with_webmock


    def connect_with_webmock
      unless @@alredy_checked_for_net_http_replacement_libs ||= false
        WebMock::NetHTTPUtility.puts_warning_for_net_http_replacement_libs_if_needed
        @@alredy_checked_for_net_http_replacement_libs = true
      end
      nil
    end
    alias_method :connect_without_webmock, :connect
    alias_method :connect, :connect_with_webmock

    def build_net_http_response(webmock_response, &block)
      response = Net::HTTPResponse.send(:response_class, webmock_response.status[0].to_s).new("1.0", webmock_response.status[0].to_s, webmock_response.status[1])
      response.instance_variable_set(:@body, webmock_response.body)
      webmock_response.headers.to_a.each { |name, value| response[name] = value }

      response.instance_variable_set(:@read, true)

      response.extend StubResponse

      raise Timeout::Error, "execution expired" if webmock_response.should_timeout

      webmock_response.raise_error_if_any

      yield response if block_given?

      response
    end

  end

end

module WebMock
  module NetHTTPUtility

    def self.request_signature_from_request(net_http, request, body = nil)
      protocol = net_http.use_ssl? ? "https" : "http"

      path = request.path
      path = Addressable::URI.heuristic_parse(request.path).request_uri if request.path =~ /^http/

      if request["authorization"] =~ /^Basic /
        userinfo = WebMock::Util::Headers.decode_userinfo_from_header(request["authorization"])
        userinfo = WebMock::Util::URI.encode_unsafe_chars_in_userinfo(userinfo) + "@"
      else
        userinfo = ""
      end

      uri = "#{protocol}://#{userinfo}#{net_http.address}:#{net_http.port}#{path}"
      method = request.method.downcase.to_sym

      headers = Hash[*request.to_hash.map {|k,v| [k, v]}.flatten(1)]
       
      headers.reject! {|k,v| k =~ /[Aa]uthorization/ && v.first =~ /^Basic / } #we added it to url userinfo


      if request.body_stream
        body = request.body_stream.read
        request.body_stream = nil
      end

      if body != nil && body.respond_to?(:read)
        request.set_body_internal body.read
      else
        request.set_body_internal body
      end

      WebMock::RequestSignature.new(method, uri, :body => request.body, :headers => headers)
    end


    def self.record_loaded_net_http_replacement_libs
      libs = {"RightHttpConnection" => defined?(RightHttpConnection)}
      @loaded_net_http_replacement_libs = libs.map { |name, loaded| name if loaded }.compact
    end

    def self.puts_warning_for_net_http_replacement_libs_if_needed
      libs = {"RightHttpConnection" => defined?(RightHttpConnection)}
      warnings = libs.select { |_, loaded| loaded }.
        reject { |name, _| @loaded_net_http_replacement_libs.include?(name) }.
        map do |name, _|
        <<-TEXT.gsub(/ {10}/, '')
        \e[1mWarning: #{name} was loaded after WebMock\e[0m
          * WebMock's code is being ignored, because #{name} replaces parts of
          Net::HTTP without deferring to other libraries. This will break Net::HTTP requests.
          * To fix this, just reorder your requires so that #{name} is before WebMock.
          TEXT
        end
        $stderr.puts "\n" + warnings.join("\n") + "\n" if warnings.any?
      end
    end
  end

  WebMock::NetHTTPUtility.record_loaded_net_http_replacement_libs
