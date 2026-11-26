# frozen_string_literal: true

module HTTP
  class WebMockPerform
    def initialize(request, options, &perform)
      @request = request
      @options = options
      @perform = perform
      @request_signature = nil
    end

    def exec
      replay || perform || halt
    end

    def request_signature
      unless @request_signature
        @request_signature = @request.webmock_signature
        register_request(@request_signature)
      end

      @request_signature
    end

    protected

    def response_for_request(signature)
      ::WebMock::StubRegistry.instance.response_for_request(signature)
    end

    def register_request(signature)
      ::WebMock::RequestRegistry.instance.put(signature)
    end

    def replay
      webmock_response = response_for_request request_signature

      return unless webmock_response

      features = @options.features.values
      response = nil
      exchange = ->(_request) { response = replay_response(features, webmock_response) }
      # HTTP.rb 6 instruments a request in around_request, inside the
      # HTTP::Client#perform a stub skips, so the instrumentation runs around
      # a stubbed exchange too. Other features that run around the exchange,
      # such as caching and digest_auth, don't run for a stub. The stub's
      # response is returned whatever an instrumenter returns, and also when
      # one doesn't yield, as before.
      instrumentation(features).reverse.reduce(exchange) do |inner, feature|
        ->(request) { feature.around_request(request) { |r| inner.call(r) } }
      end.call(@request)
      response || replay_response(features, webmock_response)
    end

    def instrumentation(features)
      return [] unless defined?(::HTTP::Features::Instrumentation) && ::HTTP::Feature.method_defined?(:around_request)

      features.select { |feature| feature.is_a?(::HTTP::Features::Instrumentation) }
    end

    def replay_response(features, webmock_response)
      # HTTP::Client calls on_error for an error while sending, which for a
      # stub is its timeout or error, but not for one raised while wrapping
      # the response, as the raise_error feature does for a 500.
      begin
        raise_timeout_error if webmock_response.should_timeout
        webmock_response.raise_error_if_any
      rescue ::HTTP::Error => e
        features.each { |feature| feature.on_error(@request, e) if feature.respond_to?(:on_error) }
        raise
      end

      invoke_callbacks(webmock_response, real_request: false)
      response = ::HTTP::Response.from_webmock @request, webmock_response, request_signature

      # HTTP.rb 6.0+ wraps responses in reverse feature order
      features = features.reverse if HTTP::VERSION >= "6.0.0"
      features.each { |feature| response = feature.wrap_response(response) }
      response
    end

    def raise_timeout_error
      raise Errno::ETIMEDOUT if HTTP::VERSION < "1.0.0"
      raise HTTP::TimeoutError, "connection error: #{Errno::ETIMEDOUT.new}"
    end

    def perform
      return unless ::WebMock.net_connect_allowed?(request_signature.uri)
      response = @perform.call
      invoke_callbacks(webmock_response_for(response), real_request: true)
      response
    end

    # The response that callbacks get for a real one. HTTP.rb's auto_inflate
    # feature inflates the body and keeps the headers of the compressed one.
    # WebMock replays a stub through the features, so a stub returning these
    # headers with the inflated body, such as a VCR cassette, would be
    # inflated again. Callbacks get headers that describe the inflated body.
    def webmock_response_for(response)
      return response.to_webmock unless ::WebMock::CallbackRegistry.any_callbacks? && auto_inflate?

      inflated = false
      webmock_response = response.to_webmock { |body| inflated = reads_from_inflater?(body) }
      describe_inflated_body(webmock_response) if inflated
      webmock_response
    end

    # Whether the client inflates with HTTP.rb's own feature. A subclass may
    # do anything with the headers and the body, so its responses are left
    # as they are.
    def auto_inflate?
      return false unless defined?(::HTTP::Features::AutoInflate)

      features = @options.features.values.grep(::HTTP::Features::AutoInflate)
      features.any? && features.all? { |feature| exactly?(::HTTP::Features::AutoInflate, feature) }
    end

    # Only evidence counts, so that callbacks never get other headers for a
    # body that is still compressed. HTTP.rb shows inflation only in the
    # stream the body reads from, which its logging feature may wrap. With
    # HTTP.rb 6's caching feature the body is a String, which shows nothing.
    # A subclass may do anything with what it reads, so it shows nothing too.
    def reads_from_inflater?(body)
      return false unless defined?(::HTTP::Response::Inflater) && exactly?(::HTTP::Response::Body, body)

      stream = body.instance_variable_get(:@stream)
      if defined?(::HTTP::Features::Logging::BodyLogger) && exactly?(::HTTP::Features::Logging::BodyLogger, stream)
        stream = stream.instance_variable_get(:@stream)
      end
      exactly?(::HTTP::Response::Inflater, stream)
    end

    CLASS_OF = ::Kernel.instance_method(:class)
    private_constant :CLASS_OF

    # Asks Ruby and not the object, which may say anything of itself.
    def exactly?(klass, object)
      klass.equal?(CLASS_OF.bind(object).call)
    end

    # No Content-Encoding, as for a body Net::HTTP inflates, and its own
    # length. A response with an empty body, such as one to HEAD, keeps its
    # headers: they tell of a body that isn't there to be inflated again.
    def describe_inflated_body(webmock_response)
      return if webmock_response.body.empty?

      headers = webmock_response.headers
      headers.delete("Content-Encoding")
      headers["Content-Length"] = webmock_response.body.bytesize.to_s if headers.key?("Content-Length")
    end

    def halt
      raise ::WebMock::NetConnectNotAllowedError.new request_signature
    end

    def invoke_callbacks(webmock_response, options = {})
      ::WebMock::CallbackRegistry.invoke_callbacks(
        options.merge({ lib: :http_rb }),
        request_signature,
        webmock_response
      )
    end
  end
end
