# frozen_string_literal: true

module WebMock

  def self.included(clazz)
    WebMock::Deprecation.warning("include WebMock is deprecated. Please include WebMock::API instead")
    if clazz.instance_methods.map(&:to_s).include?('request')
      warn "WebMock#request was not included in #{clazz} to avoid name collision"
    else
      clazz.class_eval do
        def request(method, uri)
          WebMock::Deprecation.warning("WebMock#request is deprecated. Please use WebMock::API#a_request method instead")
          WebMock.a_request(method, uri)
        end
      end
    end
  end

  include WebMock::API
  extend WebMock::API

  class << self
    alias :request :a_request
  end

  def self.version
    VERSION
  end

  def self.disable!(options = {})
    except = [options[:except]].flatten.compact
    HttpLibAdapterRegistry.instance.each_adapter do |name, adapter|
      adapter.enable!
      adapter.disable! unless except.include?(name)
    end
  end

  def self.enable!(options = {})
    except = [options[:except]].flatten.compact
    HttpLibAdapterRegistry.instance.each_adapter do |name, adapter|
      adapter.disable!
      adapter.enable! unless except.include?(name)
    end
  end

  def self.allow_net_connect!(options = {})
    Config.instance.allow_net_connect = true
    Config.instance.net_http_connect_on_start = options[:net_http_connect_on_start]
  end

  def self.disable_net_connect!(options = {})
    Config.instance.allow_net_connect = false
    Config.instance.allow_localhost = options[:allow_localhost]
    Config.instance.allow = options[:allow]
    Config.instance.net_http_connect_on_start = options[:net_http_connect_on_start]
  end

  class << self
    alias :enable_net_connect!   :allow_net_connect!
    alias :disallow_net_connect! :disable_net_connect!
  end

  def self.net_connect_allowed?(uri = nil)
    return !!Config.instance.allow_net_connect if uri.nil?

    if uri.is_a?(String)
      uri = WebMock::Util::URI.normalize_uri(uri)
    end

    !!Config.instance.allow_net_connect ||
    ( Config.instance.allow_localhost && WebMock::Util::URI.is_uri_localhost?(uri) ||
      Config.instance.allow && net_connect_explicit_allowed?(Config.instance.allow, uri) )
  end

  def self.net_http_connect_on_start?(uri)
    allowed = Config.instance.net_http_connect_on_start || false

    if [true, false].include?(allowed)
      allowed
    else
      net_connect_explicit_allowed?(allowed, uri)
    end
  end

  def self.net_connect_explicit_allowed?(allowed, uri=nil)
    case allowed
    when Array
      allowed.any? { |allowed_item| net_connect_explicit_allowed?(allowed_item, uri) }
    when Regexp
      allowed.match?(uri.to_s) ||
      (uri.port == uri.default_port && allowed.match?(uri.omit(:port).to_s))
    when String
      allowed == uri.host ||
      allowed == "#{uri.host}:#{uri.port}" ||
      net_connect_allowed_url?(allowed, uri)
    else
      if allowed.respond_to?(:call)
        allowed.call(uri)
      end
    end
  end

  def self.net_connect_allowed_url?(allowed, uri)
    return false unless allowed.match?(%r{\Ahttps?://}i)

    # Normalization turns an empty path into "/", so check the original URL.
    allowed_uri = Addressable::URI.parse(allowed)
    allow_any_path = allowed_uri.path.empty? && allowed_uri.query.nil?

    # Connection URIs have no request path to match yet.
    return false if uri.path.empty? && !allowed_uri.path.empty?

    allowed_uri = WebMock::Util::URI.normalize_uri(allowed_uri)
    request_uri = WebMock::Util::URI.normalize_uri(uri)

    return false unless allowed_uri.origin == request_uri.origin
    return true if allow_any_path

    allowed_uri.path == request_uri.path && allowed_uri.query == request_uri.query
  rescue Addressable::URI::InvalidURIError
    false
  end
  private_class_method :net_connect_allowed_url?

  def self.show_body_diff!
    Config.instance.show_body_diff = true
  end

  def self.hide_body_diff!
    Config.instance.show_body_diff = false
  end

  def self.show_body_diff?
    Config.instance.show_body_diff
  end

  def self.hide_stubbing_instructions!
    Config.instance.show_stubbing_instructions = false
  end

  def self.show_stubbing_instructions!
    Config.instance.show_stubbing_instructions = true
  end

  def self.show_stubbing_instructions?
    Config.instance.show_stubbing_instructions
  end

  def self.reset!
    WebMock::RequestRegistry.instance.reset!
    WebMock::StubRegistry.instance.reset!
  end

  def self.reset_webmock
    WebMock::Deprecation.warning("WebMock.reset_webmock is deprecated. Please use WebMock.reset! method instead")
    reset!
  end

  def self.reset_callbacks
    WebMock::CallbackRegistry.reset
  end

  def self.after_request(options={}, &block)
    WebMock::CallbackRegistry.add_callback(options, block)
  end

  def self.registered_request?(request_signature)
    WebMock::StubRegistry.instance.registered_request?(request_signature)
  end

  def self.print_executed_requests
    puts WebMock::RequestExecutionVerifier.executed_requests_message
  end

  def self.globally_stub_request(order = :before_local_stubs, &block)
    WebMock::StubRegistry.instance.register_global_stub(order, &block)
  end

  %w(
    allow_net_connect!
    disable_net_connect!
    net_connect_allowed?
    reset_webmock
    reset_callbacks
    after_request
    registered_request?
  ).each do |method|
    self.class_eval(%Q(
                      def #{method}(*args, &block)
                        WebMock::Deprecation.warning("WebMock##{method} instance method is deprecated. Please use WebMock.#{method} class method instead")
                        WebMock.#{method}(*args, &block)
                          end
    ))
  end
end
