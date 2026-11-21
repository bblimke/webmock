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
      invoke_callbacks(response.to_webmock, real_request: true)
      response
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
