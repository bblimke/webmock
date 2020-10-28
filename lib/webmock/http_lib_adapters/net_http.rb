require 'net/http'
require 'net/https'
require 'stringio'
require File.join(File.dirname(__FILE__), 'net_http_response')


module WebMock
  module HttpLibAdapters
    class NetHttpAdapter < HttpLibAdapter
      adapter_for :net_http

      OriginalNetHTTP = Net::HTTP unless const_defined?(:OriginalNetHTTP)
      OriginalNetBufferedIO = Net::BufferedIO unless const_defined?(:OriginalNetBufferedIO)

      def self.enable!
        Net.send(:remove_const, :BufferedIO)
        Net.send(:remove_const, :HTTP)
        Net.send(:remove_const, :HTTPSession)
        Net.send(:const_set, :HTTP, @webMockNetHTTP)
        Net.send(:const_set, :HTTPSession, @webMockNetHTTP)
        Net.send(:const_set, :BufferedIO, Net::WebMockNetBufferedIO)
      end

      def self.disable!
        Net.send(:remove_const, :BufferedIO)
        Net.send(:remove_const, :HTTP)
        Net.send(:remove_const, :HTTPSession)
        Net.send(:const_set, :HTTP, OriginalNetHTTP)
        Net.send(:const_set, :HTTPSession, OriginalNetHTTP)
        Net.send(:const_set, :BufferedIO, OriginalNetBufferedIO)

        #copy all constants from @webMockNetHTTP to original Net::HTTP
        #in case any constants were added to @webMockNetHTTP instead of Net::HTTP
        #after WebMock was enabled.
        #i.e Net::HTTP::DigestAuth
        @webMockNetHTTP.constants.each do |constant|
          if !OriginalNetHTTP.constants.map(&:to_s).include?(constant.to_s)
            OriginalNetHTTP.send(:const_set, constant, @webMockNetHTTP.const_get(constant))
          end
        end
      end

      @webMockNetHTTP = Class.new(Net::HTTP) do
        class << self
          def socket_type
            StubSocket
          end

          if Module.method(:const_defined?).arity == 1
            def const_defined?(name)
              super || self.superclass.const_defined?(name)
            end
          else
            def const_defined?(name, inherit=true)
              super || self.superclass.const_defined?(name, inherit)
            end
          end

          if Module.method(:const_get).arity != 1
            def const_get(name, inherit=true)
              super
            rescue NameError
              self.superclass.const_get(name, inherit)
            end
          end

          if Module.method(:constants).arity != 0
            def constants(inherit=true)
              (super + self.superclass.constants(inherit)).uniq
            end
          end
        end

        def request(request, body = nil, &block)
          request_signature = WebMock::NetHTTPUtility.request_signature_from_request(self, request, body)

          WebMock::RequestRegistry.instance.requested_signatures.put(request_signature)

          if webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
            @socket = Net::HTTP.socket_type.new
            WebMock::CallbackRegistry.invoke_callbacks(
              {lib: :net_http}, request_signature, webmock_response)
            build_net_http_response(webmock_response, &block)
          elsif WebMock.net_connect_allowed?(request_signature.uri)
            check_right_http_connection
            after_request = lambda do |response|
              if WebMock::CallbackRegistry.any_callbacks?
                webmock_response = build_webmock_response(response)
                WebMock::CallbackRegistry.invoke_callbacks(
                  {lib: :net_http, real_request: true}, request_signature, webmock_response)
              end
              response.extend Net::WebMockHTTPResponse
              block.call response if block
              response
            end
            super_with_after_request = lambda {
              response = super(request, nil, &nil)
              after_request.call(response)
            }
            if started?
              if WebMock::Config.instance.net_http_connect_on_start
                super_with_after_request.call
              else
                start_with_connect_without_finish {
                  super_with_after_request.call
                }
              end
            else
              start_with_connect {
                super_with_after_request.call
              }
            end
          else
            raise WebMock::NetConnectNotAllowedError.new(request_signature)
          end
        end

        def start_without_connect
          raise IOError, 'HTTP session already opened' if @started
          if block_given?
            begin
              @started = true
              return yield(self)
            ensure
              do_finish
            end
          end
          @started = true
          self
        end


        def start_with_connect_without_finish  # :yield: http
          if block_given?
            begin
              do_start
              return yield(self)
            end
          end
          do_start
          self
        end

        alias_method :start_with_connect, :start

        def start(&block)
          if WebMock::Config.instance.net_http_connect_on_start
            super(&block)
          else
            start_without_connect(&block)
          end
        end

        def build_net_http_response(webmock_response, &block)
          response = Net::HTTPResponse.send(:response_class, webmock_response.status[0].to_s).new("1.0", webmock_response.status[0].to_s, webmock_response.status[1])
          body = webmock_response.body
          body = nil if webmock_response.status[0].to_s == '204'

          response.instance_variable_set(:@body, body)
          webmock_response.headers.to_a.each do |name, values|
            values = [values] unless values.is_a?(Array)
            values.each do |value|
              response.add_field(name, value)
            end
          end

          response.instance_variable_set(:@read, true)

          response.extend Net::WebMockHTTPResponse

          if webmock_response.should_timeout
            raise timeout_exception, "execution expired"
          end

          webmock_response.raise_error_if_any

          yield response if block_given?

          response
        end

        def timeout_exception
          if defined?(Net::OpenTimeout)
            # Ruby 2.x
            Net::OpenTimeout
          else
            # Fallback, if things change
            Timeout::Error
          end
        end

        def build_webmock_response(net_http_response)
          webmock_response = WebMock::Response.new
          webmock_response.status = [
             net_http_response.code.to_i,
             net_http_response.message]
          webmock_response.headers = net_http_response.to_hash
          webmock_response.body = net_http_response.body
          webmock_response
        end


        def check_right_http_connection
          unless @@alredy_checked_for_right_http_connection ||= false
            WebMock::NetHTTPUtility.puts_warning_for_right_http_if_needed
            @@alredy_checked_for_right_http_connection = true
          end
        end
      end
      @webMockNetHTTP.version_1_2
      [
        [:Get, Net::HTTP::Get],
        [:Post, Net::HTTP::Post],
        [:Put, Net::HTTP::Put],
        [:Delete, Net::HTTP::Delete],
        [:Head, Net::HTTP::Head],
        [:Options, Net::HTTP::Options]
      ].each do |c|
        @webMockNetHTTP.const_set(c[0], c[1])
      end
    end
  end
end

# patch for StringIO behavior in Ruby 2.2.3
# https://github.com/bblimke/webmock/issues/558
class PatchedStringIO < StringIO #:nodoc:

  alias_method :orig_read_nonblock, :read_nonblock

  def read_nonblock(size, *args, **kwargs)
    args.reject! {|arg| !arg.is_a?(Hash)}
    orig_read_nonblock(size, *args, **kwargs)
  end

end

class StubSocket #:nodoc:

  attr_accessor :read_timeout, :continue_timeout, :write_timeout

  def initialize(*args)
  end

  def closed?
    @closed ||= true
  end

  def close
  end

  def readuntil(*args)
  end

  def io
    @io ||= StubIO.new
  end

  class StubIO
    def setsockopt(*args); end
  end
end

module Net  #:nodoc: all

  class WebMockNetBufferedIO < BufferedIO
    def initialize(io, *args, **kwargs)
      io = case io
      when Socket, OpenSSL::SSL::SSLSocket, IO
        io
      when StringIO
        PatchedStringIO.new(io.string)
      when String
        PatchedStringIO.new(io)
      end
      raise "Unable to create local socket" unless io

      # Prior to 2.4.0 `BufferedIO` only takes a single argument (`io`) with no
      # options. Here we pass through our full set of arguments only if we're
      # on 2.4.0 or later, and use a simplified invocation otherwise.
      if RUBY_VERSION >= '2.4.0'
        super
      else
        super(io)
      end
    end

    if RUBY_VERSION >= '2.6.0'
      # https://github.com/ruby/ruby/blob/7d02441f0d6e5c9d0a73a024519eba4f69e36dce/lib/net/protocol.rb#L208
      # Modified version of method from ruby, so that nil is always passed into orig_read_nonblock to avoid timeout
      def rbuf_fill
        case rv = @io.read_nonblock(BUFSIZE, nil, exception: false)
        when String
          return if rv.nil?
          @rbuf << rv
          rv.clear
          return
        when :wait_readable
          @io.to_io.wait_readable(@read_timeout) or raise Net::ReadTimeout
        when :wait_writable
          @io.to_io.wait_writable(@read_timeout) or raise Net::ReadTimeout
        when nil
          raise EOFError, 'end of file reached'
        end while true
      end
    end
  end

end


module WebMock
  module NetHTTPUtility

    def self.request_signature_from_request(net_http, request, body = nil)
      protocol = net_http.use_ssl? ? "https" : "http"

      path = request.path

      if path.respond_to?(:request_uri) #https://github.com/bblimke/webmock/issues/288
        path = path.request_uri
      end

      path = WebMock::Util::URI.heuristic_parse(path).request_uri if path =~ /^http/

      uri = "#{protocol}://#{net_http.address}:#{net_http.port}#{path}"
      method = request.method.downcase.to_sym

      headers = Hash[*request.to_hash.map {|k,v| [k, v]}.inject([]) {|r,x| r + x}]
      validate_headers(headers)

      if request.body_stream
        body = request.body_stream.read
        request.body_stream = nil
      end

      if body != nil && body.respond_to?(:read)
        request.set_body_internal body.read
      else
        request.set_body_internal body
      end

      WebMock::RequestSignature.new(method, uri, body: request.body, headers: headers)
    end

    def self.validate_headers(headers)
      # For Ruby versions < 2.3.0, if you make a request with headers that are symbols
      # Net::HTTP raises a NoMethodError
      #
      # WebMock normalizes headers when creating a RequestSignature,
      # and will update all headers from symbols to strings.
      #
      # This could create a false positive in a test suite with WebMock.
      #
      # So before this point, WebMock raises an ArgumentError if any of the headers are symbols
      # instead of the cryptic NoMethodError "undefined method `split' ...` from Net::HTTP
      if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new('2.3.0')
        header_as_symbol = headers.keys.find {|header| header.is_a? Symbol}
        if header_as_symbol
          raise ArgumentError.new("Net:HTTP does not accept headers as symbols")
        end
      end
    end

    def self.check_right_http_connection
      @was_right_http_connection_loaded = defined?(RightHttpConnection)
    end

    def self.puts_warning_for_right_http_if_needed
      if !@was_right_http_connection_loaded && defined?(RightHttpConnection)
        $stderr.puts "\nWarning: RightHttpConnection has to be required before WebMock is required !!!\n"
      end
    end

  end
end

WebMock::NetHTTPUtility.check_right_http_connection
