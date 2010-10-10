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

  def a_request(method, uri)
    RequestPattern.new(method, uri)
  end

  class << self
    alias :request :a_request
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

  def self.allow_net_connect!
    Config.instance.allow_net_connect = true
  end

  def self.disable_net_connect!(options = {})
    Config.instance.allow_net_connect = false
    Config.instance.allow_localhost = options[:allow_localhost]
    Config.instance.allow = options[:allow]
  end

  def self.net_connect_allowed?(uri = nil)
    if uri.is_a?(String)
      uri = WebMock::Util::URI.normalize_uri(uri)
    end
    Config.instance.allow_net_connect ||
      (Config.instance.allow_localhost && is_uri_localhost?(uri)) ||
      Config.instance.allow && Config.instance.allow.include?(uri.host)
  end

  def self.response_for_request(request_signature, &block)
    RequestRegistry.instance.response_for_request(request_signature, &block)
  end

  def self.reset_webmock
    WebMock::RequestRegistry.instance.reset_webmock
  end

  def self.reset_callbacks
    WebMock::CallbackRegistry.reset
  end
  
  def self.after_request(options={}, &block)
    CallbackRegistry.add_callback(options, block)
  end
  
  private
  
  def is_uri_localhost?(uri)
    uri.is_a?(Addressable::URI) && 
    %w(localhost 127.0.0.1 0.0.0.0).include?(uri.host)
  end

  def assertion_failure(message)
    raise message
  end

end
