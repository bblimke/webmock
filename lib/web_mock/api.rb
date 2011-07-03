module WebMock
  # API provides the methods used in any testing framework
  module API
    extend self

    # Register a new stubbed request
    #
    # @param [Symbol] method an HTTP method or `:any`
    # @return [WebMock::StubRegistry]
    def stub_request(method, uri)
      WebMock::StubRegistry.instance.register_request_stub(WebMock::RequestStub.new(method, uri))
    end

    alias_method :stub_http_request, :stub_request

    # Create a new request pattern with a method and URI
    #
    # @param [Symbol] method an HTTP method or `:any`
    # @return [WebMock::RequestPattern]
    def a_request(method, uri)
      WebMock::RequestPattern.new(method, uri)
    end

    class << self
      alias :request :a_request
    end

    # Assert that a request has been made
    #
    # @param [Symbol] method the HTTP method
    # @param [String] uri request URI
    # @param [Hash] options
    #   @option [Hash] :headers
    #   @option [String] :body
    # @yield block to pass to {WebMock::RequestPattern}
    # @raise [RuntimeError] if a matching request has not been made
    def assert_requested(method, uri, options = {}, &block)
      expected_times_executed = options.delete(:times) || 1
      request = WebMock::RequestPattern.new(method, uri, options).with(&block)
      verifier = WebMock::RequestExecutionVerifier.new(request, expected_times_executed)
      WebMock::AssertionFailure.failure(verifier.failure_message) unless verifier.matches?
    end

    # Assert that a request has not been made
    #
    # @param [Symbol] method the HTTP method
    # @param [String] uri request URI
    # @param [Hash] options
    #   @option [Hash] :headers
    #   @option [String] :body
    # @yield block to pass to {WebMock::RequestPattern}
    # @raise [RuntimeError] if a matching request has been made
    def assert_not_requested(method, uri, options = {}, &block)
      request = WebMock::RequestPattern.new(method, uri, options).with(&block)
      verifier = WebMock::RequestExecutionVerifier.new(request, options.delete(:times))
      WebMock::AssertionFailure.failure(verifier.negative_failure_message) unless verifier.does_not_match?
    end
  end
end
