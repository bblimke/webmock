module WebMock
  module API
    extend self

    def stub_request(method, uri)
      WebMock::StubRegistry.instance.
        register_request_stub(WebMock::RequestStub.new(method, uri))
    end

    alias_method :stub_http_request, :stub_request

    def a_request(method, uri)
      WebMock::RequestPattern.new(method, uri)
    end

    class << self
      alias :request :a_request
    end


    def assert_requested(*args, &block)
      if not args[0].is_a?(WebMock::RequestStub)
        args = convert_uri_method_and_options_to_request_and_options(*args, &block)
      elsif block
        raise ArgumentError, "assert_requested with a stub object, doesn't accept blocks"
      end
      assert_request_requested(*args)
    end

    def assert_not_requested(*args, &block)
      if not args[0].is_a?(WebMock::RequestStub)
        args = convert_uri_method_and_options_to_request_and_options(*args, &block)
      elsif block
        raise ArgumentError, "assert_not_requested with a stub object, doesn't accept blocks"
      end
      assert_request_not_requested(*args)
    end

    def hash_including(expected)
      if defined?(::RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher)
        RSpec::Mocks::ArgumentMatchers::HashIncludingMatcher.new(expected)
      elsif defined?(::Spec::Mocks::ArgumentMatchers::HashIncludingMatcher)
        Spec::Mocks::ArgumentMatchers::HashIncludingMatcher.new(expected)
      else
        WebMock::Matchers::HashIncludingMatcher.new(expected)
      end
    end

    def remove_request_stub(stub)
      WebMock::StubRegistry.instance.remove_request_stub(stub)
    end

    private

    def convert_uri_method_and_options_to_request_and_options(*args, &block)
      request = WebMock::RequestPattern.new(*args).with(&block)
      [request, args[2] || {}]
    end

    def assert_request_requested(request, options = {})
      verifier = WebMock::RequestExecutionVerifier.new(request, options.delete(:times) || 1)
      WebMock::AssertionFailure.failure(verifier.failure_message) unless verifier.matches?
    end

    def assert_request_not_requested(request, options = {})
      verifier = WebMock::RequestExecutionVerifier.new(request, options.delete(:times))
      WebMock::AssertionFailure.failure(verifier.negative_failure_message) unless verifier.does_not_match?
    end

  end
end
