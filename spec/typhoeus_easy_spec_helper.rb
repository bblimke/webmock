require 'ostruct'

module TyphoeusEasySpecHelper
  class FakeTyphoeusEasyError < StandardError; end

  def http_request(method, uri, options = {}, &block)
    uri = Addressable::URI.heuristic_parse(uri)
    
    easy = Typhoeus::Easy.new
    easy.method   = method
    easy.url      = uri.omit(:userinfo).to_s
    easy.auth = { :username => uri.user, :password => uri.password } if uri.user
    easy.request_body = options[:body] if options[:body]
    easy.headers = options[:headers] if options[:headers]
    easy.timeout  = 2000
    easy.connect_timeout = 2000

    easy.perform

    # status, response_headers = Curl::Easy::WebmockHelper.parse_header_string(curl.header_str)
    raise FakeTyphoeusEasyError.new if easy.response_code.to_s == "0"
    response = Typhoeus::Response.new(:headers => easy.response_header)
    OpenStruct.new(
      :body => easy.response_body,
      :headers => WebMock::Util::Headers.normalize_headers(join_array_values(response.headers_hash)),
      :status => easy.response_code.to_s,
      :message => response.status_message
    )
  end

  def client_timeout_exception_class
    Curl::Err::TimeoutError
  end

  def connection_refused_exception_class
    FakeTyphoeusEasyError
  end

  def setup_expectations_for_real_request(options = {})
    #TODO
  end

  def http_library
    :typhoeus
  end

end
