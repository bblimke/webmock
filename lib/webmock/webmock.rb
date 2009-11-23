module WebMock

  def stub_request(method, uri)
    RequestRegistry.instance.register_request_stub(RequestStub.new(method, uri))
  end
  
  alias_method :stub_http_request, :stub_request

  def request(method, uri)
    RequestProfile.new(method, uri)
  end

  def assert_requested(method, uri, options = {})
    expected_times_executed = options.delete(:times) || 1
    request = RequestProfile.new(method, uri, options[:body], options[:headers])
    verifier = RequestExecutionVerifier.new(request, expected_times_executed)
    assertion_failure(verifier.failure_message) unless verifier.matches?
  end

  def assert_not_requested(method, uri, options = {})
    request = RequestProfile.new(method, uri, options[:body], options[:headers])
    verifier = RequestExecutionVerifier.new(request, options.delete(:times))
    assertion_failure(verifier.negative_failure_message) unless verifier.does_not_match?
  end

  def self.allow_net_connect!
    Config.instance.allow_net_connect = true
  end

  def self.disable_net_connect!
    Config.instance.allow_net_connect = false
  end

  def self.net_connect_allowed?
    Config.instance.allow_net_connect
  end

  def self.registered_request?(request_signature)
    RequestRegistry.instance.registered_request?(request_signature)
  end

  def self.response_for_request(request_signature, &block)
    RequestRegistry.instance.response_for_request(request_signature, &block)
  end

  def reset_webmock
    WebMock::RequestRegistry.instance.reset_webmock
  end
  
  private
  
  def assertion_failure(message)
    raise message
  end

end
