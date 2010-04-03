module WebMock
  extend self

  def stub_request(method, uri)
    RequestRegistry.instance.register_request_stub(RequestStub.new(method, uri))
  end
  
  alias_method :stub_http_request, :stub_request

  def request(method, uri)
    RequestProfile.new(method, uri)
  end

  def assert_requested(method, uri, options = {}, &block)
    expected_times_executed = options.delete(:times) || 1
    request = RequestProfile.new(method, uri, options).with(&block)
    verifier = RequestExecutionVerifier.new(request, expected_times_executed)
    assertion_failure(verifier.failure_message) unless verifier.matches?
  end

  def assert_not_requested(method, uri, options = {}, &block)
    request = RequestProfile.new(method, uri, options).with(&block)
    verifier = RequestExecutionVerifier.new(request, options.delete(:times))
    assertion_failure(verifier.negative_failure_message) unless verifier.does_not_match?
  end

  def allow_net_connect!
    Config.instance.allow_net_connect = true
  end

  def disable_net_connect!(localhost = false)
    Config.instance.allow_net_connect = false
    Config.instance.allow_localhost = localhost
  end

  def net_connect_allowed?(uri = nil)
    if uri.class == String
      uri = URI::parse(uri)
    end
    Config.instance.allow_net_connect || ( Config.instance.allow_localhost && uri.is_a?(URI) && uri.host == 'localhost' )
  end

  def registered_request?(request_signature)
    RequestRegistry.instance.registered_request?(request_signature)
  end

  def response_for_request(request_signature, &block)
    RequestRegistry.instance.response_for_request(request_signature, &block)
  end

  def reset_webmock
    WebMock::RequestRegistry.instance.reset_webmock
  end
  
  def assertion_failure(message)
    raise message
  end

end
