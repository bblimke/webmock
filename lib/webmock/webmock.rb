module WebMock
  
  def self.included(clazz)
    $stderr.puts "include WebMock is deprecated. Please include WebMock::API instead"
  end
  
  extend self

  include WebMock::API
  extend WebMock::API

  class << self
    alias :request :a_request
  end
  
  def self.version
    open(File.join(File.dirname(__FILE__), '../../VERSION')) { |f|
      f.read.strip
    }
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
      (Config.instance.allow_localhost && WebMock::Util::URI.is_uri_localhost?(uri)) ||
      Config.instance.allow && Config.instance.allow.include?(uri.host)
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
  
  def self.registered_request?(request_signature)
    RequestRegistry.instance.registered_request?(request_signature)
  end

end
