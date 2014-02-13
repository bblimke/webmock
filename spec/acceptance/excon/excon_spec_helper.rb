require 'ostruct'

module ExconSpecHelper

  def http_request(method, uri, options = {}, &block)
    Excon.defaults[:ssl_verify_peer] = false
    uri      = Addressable::URI.heuristic_parse(uri)
    uri      = uri.omit(:userinfo).to_s.gsub(' ', '%20')

    if Gem::Version.new(Excon::VERSION) < Gem::Version.new("0.29.0")
      options  = options.merge(:method => method, :nonblock => false) # Dup and merge
      response = Excon.new(uri).request(options, &block)
    else
      options  = options.merge(:method => method) # Dup and merge
      response = Excon.new(uri, :nonblock => false).request(options, &block)
    end

    headers  = WebMock::Util::Headers.normalize_headers(response.headers)
    headers  = headers.inject({}) do |res, (name, value)|
      res[name] = value.is_a?(Array) ? value.flatten.join(', ') : value
      res
    end

    OpenStruct.new \
      :body => response.body,
      :headers => headers,
      :status  => response.status.to_s,
      :message => ""
  end

  def client_timeout_exception_class
    Excon::Errors::Timeout
  end

  def connection_refused_exception_class
    Excon::Errors::SocketError
  end

  def http_library
    :excon
  end

end
