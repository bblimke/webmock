require 'ostruct'

module CurbSpecHelper
  def http_request(method, uri, options = {}, &block)
    uri = Addressable::URI.heuristic_parse(uri)
    body = options[:body]

    curl = curb_http_request(uri, method, body, options)

    status, response_headers =
     WebMock::HttpLibAdapters::CurbAdapter.parse_header_string(curl.header_str)

    # Deal with the fact that the HTTP spec allows multi-values headers
    # to either be a single entry with a comma-separated listed of
    # values, or multiple separate entries
    response_headers.keys.each do |k|
      v = response_headers[k]
      if v.is_a?(Array)
        response_headers[k] = v.join(', ')
      end
    end

    OpenStruct.new(
      body: curl.body_str,
      headers: WebMock::Util::Headers.normalize_headers(response_headers),
      status: curl.response_code.to_s,
      message: status
    )
  end

  def setup_request(uri, curl, options={})
    curl          ||= Curl::Easy.new
    curl.url      = uri.to_s
    if options[:basic_auth]
      curl.http_auth_types = :basic
      curl.username = options[:basic_auth][0]
      curl.password = options[:basic_auth][1]
    end
    curl.timeout  = 30
    curl.connect_timeout = 30

    if headers = options[:headers]
      headers.each {|k,v| curl.headers[k] = v }
    end

    curl
  end

  def client_timeout_exception_class
    Curl::Err::TimeoutError
  end

  def connection_refused_exception_class
    Curl::Err::ConnectionFailedError
  end

  def http_library
    :curb
  end

  module DynamicHttp
    def curb_http_request(uri, method, body, options)
      curl = setup_request(uri, nil, options)

      case method
      when :post
        curl.post_body = body
      when :put
        curl.put_data = body
      end

      curl.http(method.to_s.upcase)
      curl
    end
  end

  module NamedHttp
    def curb_http_request(uri, method, body, options)
      curl = setup_request(uri, nil, options)

      case method
      when :put, :post
        curl.send( "http_#{method}", body )
      else
        curl.send( "http_#{method}" )
      end
      curl
    end
  end

  module Perform
    def curb_http_request(uri, method, body, options)
      curl = setup_request(uri, nil, options)

      case method
      when :post
        curl.post_body = body
      when :put
        curl.put_data = body
      when :head
        curl.head = true
      when :delete
        curl.delete = true
      end

      curl.perform
      curl
    end
  end

  module ClassNamedHttp
    def curb_http_request(uri, method, body, options)
      args = ["http_#{method}", uri]
      args << body if method == :post || method == :put

      c = Curl::Easy.send(*args) do |curl|
        setup_request(uri, curl, options)
      end

      c
    end
  end

  module ClassPerform
    def curb_http_request(uri, method, body, options)
      args = ["http_#{method}", uri]
      args << body if method == :post || method == :put

      c = Curl::Easy.send(*args) do |curl|
        setup_request(uri, curl, options)

        case method
        when :post
          curl.post_body = body
        when :put
          curl.put_data = body
        when :head
          curl.head = true
        when :delete
          curl.delete = true
        end
      end

      c
    end
  end
end
