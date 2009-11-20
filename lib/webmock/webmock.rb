WebMock::Utility.record_loaded_net_http_replacement_libs
WebMock::Utility.puts_warning_for_net_http_around_advice_libs_if_needed


module WebMock

  def stub_request(method, url)
    RequestRegistry.instance.register_request_stub(RequestStub.new(method, url))
  end
  
  alias_method :stub_http_request, :stub_request

  def request(method, url)
    RequestProfile.new(method, url)
  end

  def assert_requested(method, url, options = {})
    expected_times_executed = options.delete(:times) || 1
    request = RequestProfile.new(method, url, options[:body], options[:headers])
    verifier = RequestExecutionVerifier.new(request, expected_times_executed)
    assertion_failure(verifier.failure_message) unless verifier.verify
  end

  def assert_not_requested(method, url, options = {})
    assert_requested(method, url, options.update(:times => 0))
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

  def self.registered_request?(request_profile)
    RequestRegistry.instance.registered_request?(request_profile)
  end

  def self.response_for_request(request_profile, &block)
    RequestRegistry.instance.response_for_request(request_profile, &block)
  end

  def reset_webmock
    WebMock::RequestRegistry.instance.reset_webmock
  end
  
  private
  
  def assertion_failure(message)
    raise message
  end

end
