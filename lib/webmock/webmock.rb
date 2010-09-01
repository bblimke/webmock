module WebMock
  extend self

  def self.version
    open(File.join(File.dirname(__FILE__), '../../VERSION')) { |f|
      f.read.strip
    }
  end

  def stub_request(method, uri)
    RequestRegistry.instance.register_request_stub(RequestStub.new(method, uri))
  end

  alias_method :stub_http_request, :stub_request

  def request(method, uri)
    RequestPattern.new(method, uri)
  end

  def assert_requested(method, uri, options = {}, &block)
    expected_times_executed = options.delete(:times) || 1
    request = RequestPattern.new(method, uri, options).with(&block)
    verifier = RequestExecutionVerifier.new(request, expected_times_executed)
    assertion_failure(verifier.failure_message) unless verifier.matches?
  end

  def assert_not_requested(method, uri, options = {}, &block)
    request = RequestPattern.new(method, uri, options).with(&block)
    verifier = RequestExecutionVerifier.new(request, options.delete(:times))
    assertion_failure(verifier.negative_failure_message) unless verifier.does_not_match?
  end

  def allow_net_connect!
    Config.instance.allow_net_connect = true
  end

  def disable_net_connect!(options = {})
    Config.instance.allow_net_connect = false
    Config.instance.allow_localhost = options[:allow_localhost]
    Config.instance.allow = options[:allow]
  end

  def net_connect_allowed?(uri = nil)
    if uri.is_a?(String)
      uri = WebMock::Util::URI.normalize_uri(uri)
    end
    Config.instance.allow_net_connect ||
      (Config.instance.allow_localhost && uri.is_a?(Addressable::URI) && (uri.host == 'localhost' || uri.host == '127.0.0.1')) ||
      Config.instance.allow && Config.instance.allow.include?(uri.host)
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

  def reset_callbacks
    WebMock::CallbackRegistry.reset
  end

  def assertion_failure(message)
    raise message
  end
  
  def after_request(options={}, &block)
    CallbackRegistry.add_callback(options, block)
  end

end
