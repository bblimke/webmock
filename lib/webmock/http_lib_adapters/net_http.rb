# frozen_string_literal: true

require 'net/http'
require 'net/https'
require 'stringio'
require File.join(File.dirname(__FILE__), 'net_http_response')


module WebMock
  module HttpLibAdapters
    class NetHttpAdapter < HttpLibAdapter
      adapter_for :net_http

      OriginalNetHTTP = Net::HTTP unless const_defined?(:OriginalNetHTTP)
      # This will be removed in Ruby 3.5. In Ruby 3.4, const_remove will warn.
      HAS_LEGACY_CONSTANT = Net.const_defined?(:HTTPSession)

      # Objects created while WebMock was enabled are instances of WebMock's
      # Net::HTTP class, so they check this to act like Net::HTTP once
      # WebMock is disabled.
      def self.enabled?
        @enabled
      end

      def self.enable!
        @enabled = true
        Net.send(:remove_const, :HTTP)
        Net.send(:const_set, :HTTP, @webMockNetHTTP)
        if HAS_LEGACY_CONSTANT
          remove_silently(Net, :HTTPSession)
          Net.send(:const_set, :HTTPSession, @webMockNetHTTP)
        end
      end

      def self.disable!
        @enabled = false
        Net.send(:remove_const, :HTTP)
        Net.send(:const_set, :HTTP, OriginalNetHTTP)
        if HAS_LEGACY_CONSTANT
          remove_silently(Net, :HTTPSession)
          Net.send(:const_set, :HTTPSession, OriginalNetHTTP)
        end

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

      def self.remove_silently(mod, const) #:nodoc:
        # Don't warn on removing the deprecated constant
        verbose, $VERBOSE = $VERBOSE, nil
        mod.send(:remove_const, const)
      ensure
        $VERBOSE = verbose
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
          unless webmock_enabled?
            # Reconnect for real if started with WebMock's stub socket.
            ensure_actual_connection if started?
            return super
          end

          request_signature = WebMock::NetHTTPUtility.request_signature_from_request(self, request, body)

          WebMock::RequestRegistry.instance.put(request_signature)

          if webmock_response = WebMock::StubRegistry.instance.response_for_request(request_signature)
            # Close the real connection left by an earlier request, if any.
            @socket&.close
            @socket = self.class.socket_type.new
            WebMock::CallbackRegistry.invoke_callbacks(
              {lib: :net_http}, request_signature, webmock_response)
            build_net_http_response(webmock_response, request.uri, &block)
          elsif WebMock.net_connect_allowed?(request_signature.uri)
            check_right_http_connection
            callback_options = {lib: :net_http, real_request: true}
            # Without callbacks for this request, nothing needs the body
            # before the block, so the block gets the response while
            # Net::HTTP reads it, as without WebMock, and can stream the
            # body or set decode_content. With callbacks, such as VCR's,
            # the body is read first, so they get all of it.
            stream = block && !WebMock::CallbackRegistry.any_callbacks_for?(callback_options)
            after_request = lambda do |response|
              # Checked again, so that callbacks registered while the
              # request was made get the response too, as before. A request
              # that streams to its block doesn't come here, so callbacks
              # registered after it was sent don't get its response.
              if WebMock::CallbackRegistry.any_callbacks_for?(callback_options)
                webmock_response = build_webmock_response(response)
                WebMock::CallbackRegistry.invoke_callbacks(callback_options, request_signature, webmock_response)
              end
              response.extend Net::WebMockHTTPResponse
              # Net::HTTP has read the body and applied its encoding already
              response.instance_variable_set(:@__body_encoding_applied, true)
              block.call response if block
              response
            end
            real_request = lambda {
              next super(request, nil, &block) if stream

              after_request.call(super(request, nil, &nil))
            }
            if started?
              ensure_actual_connection
              real_request.call
            else
              start_with_connect {
                real_request.call
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
              @socket = self.class.socket_type.new
              @started = true
              return yield(self)
            ensure
              do_finish
            end
          end
          @socket = self.class.socket_type.new
          @started = true
          self
        end

        def ensure_actual_connection
          if @socket.is_a?(StubSocket)
            # Keep the closed stub socket, so a failed connect is retried.
            @socket.close
            do_start
          end
        end

        alias_method :start_with_connect, :start

        def start(&block)
          return super unless webmock_enabled?

          uri = Addressable::URI.parse(WebMock::NetHTTPUtility.get_uri(self))

          if WebMock.net_http_connect_on_start?(uri)
            super(&block)
          else
            start_without_connect(&block)
          end
        end

        def build_net_http_response(webmock_response, request_uri, &block)
          response = Net::HTTPResponse.send(:response_class, webmock_response.status[0].to_s).new("1.0", webmock_response.status[0].to_s, webmock_response.status[1])
          body = webmock_response.body
          body = nil if webmock_response.status[0].to_s == '204'

          # A copy, so that changing the response body, for example its
          # encoding, does not change the stubbed body
          response.instance_variable_set(:@body, body&.dup)
          webmock_response.headers.to_a.each do |name, values|
            values = [values] unless values.is_a?(Array)
            values.each do |value|
              response.add_field(name, value)
            end
          end

          response.instance_variable_set(:@read, true)

          response.uri = request_uri
          response.body_encoding = response_body_encoding if respond_to?(:response_body_encoding)

          response.extend Net::WebMockHTTPResponse

          if webmock_response.should_timeout
            raise Net::OpenTimeout, "execution expired"
          end

          webmock_response.raise_error_if_any

          yield response if block_given?
          response.send(:webmock_apply_body_encoding)

          response
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
          unless @@already_checked_for_right_http_connection ||= false
            WebMock::NetHTTPUtility.puts_warning_for_right_http_if_needed
            @@already_checked_for_right_http_connection = true
          end
        end

        private

        def webmock_enabled?
          WebMock::HttpLibAdapters::NetHttpAdapter.enabled?
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

class StubSocket #:nodoc:

  attr_accessor :read_timeout, :continue_timeout, :write_timeout

  def initialize(*args)
    @closed = false
  end

  def closed?
    @closed
  end

  def close
    @closed = true
    nil
  end

  def readuntil(*args)
  end

  def io
    @io ||= StubIO.new
  end

  class StubIO
    def setsockopt(*args); end
    def peer_cert; end
    def peeraddr; ["AF_INET", 443, "127.0.0.1", "127.0.0.1"] end
    def ssl_version; "TLSv1.3" end
    def cipher; ["TLS_AES_128_GCM_SHA256", "TLSv1.3", 128, 128] end
  end
end

module WebMock
  module NetHTTPUtility

    def self.request_signature_from_request(net_http, request, body = nil)
      path = request.path

      if path.respond_to?(:request_uri) #https://github.com/bblimke/webmock/issues/288
        path = path.request_uri
      end

      path = WebMock::Util::URI.heuristic_parse(path).request_uri if path =~ /^http/
      # OPTIONS * (asterisk form) has no path; a URI can only hold it as /*
      path = "/*" if path == "*" && request.method == "OPTIONS"

      uri = get_uri(net_http, path)
      method = request.method.downcase.to_sym

      headers = Hash[*request.to_hash.map {|k,v| [k, v]}.inject([]) {|r,x| r + x}]

      if request.body_stream
        body = read_body_stream(request.body_stream)
        request.body_stream = nil
      end

      # A form set with #set_form is encoded by Net::HTTP when it sends the
      # request. The request is left as it is, so it is sent as without
      # WebMock and encodes its form again when sent again, and the
      # signature gets the body it sends.
      form = request.instance_variable_get(:@body_data)
      if form && body.nil? && request.body.nil?
        return WebMock::RequestSignature.new(method, uri, body: form_body(request, form), headers: headers)
      end

      if body != nil && body.respond_to?(:read)
        request.set_body_internal body.read
      else
        request.set_body_internal body
      end

      WebMock::RequestSignature.new(method, uri, body: request.body, headers: headers)
    end

    # Net::HTTP reads a body stream with IO.copy_stream, which always passes
    # a length, so some streams only accept #read with one. Such a stream is
    # read in chunks. A stream that answers #read only through method_missing
    # is read without a length, as before.
    def self.read_body_stream(stream)
      arity = begin
        stream.method(:read).arity
      rescue NameError
        -1
      end
      return stream.read if arity == 0 || arity == -1

      body = String.new
      # As IO.copy_stream reads it: with a buffer, unless read takes only a
      # length, and until it returns nil or an empty string, or raises
      # EOFError.
      buffer = String.new
      begin
        loop do
          chunk = arity == 1 ? stream.read(16 * 1024) : stream.read(16 * 1024, buffer)
          break if chunk.nil? || chunk.empty?

          begin
            body << chunk
          rescue Encoding::CompatibilityError
            # Chunks in incompatible encodings are joined as bytes.
            body.force_encoding(Encoding::BINARY) << chunk.b
          end
        end
      rescue EOFError
      end
      body
    end

    # The body Net::HTTPGenericRequest#send_request_with_body_data sends for
    # a URL encoded form given as a Hash or an Array of pairs, which Net::HTTP
    # encodes again when it sends the request. A multipart form, or a form
    # given as another Enumerable, which may be read only once, gets no body,
    # as before.
    def self.form_body(request, form)
      return unless form.is_a?(Hash) || form.is_a?(Array)
      return if request.content_type =~ /\Amultipart\/form-data\z/i

      URI.encode_www_form(form)
    end

    def self.get_uri(net_http, path = nil)
      protocol = net_http.use_ssl? ? "https" : "http"

      hostname = net_http.address
      hostname = "[#{hostname}]" if /\A\[.*\]\z/ !~ hostname && /:/ =~ hostname

      "#{protocol}://#{hostname}:#{net_http.port}#{path}"
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
