module HTTPClientSpecHelper
  class << self
    attr_accessor :async_mode
  end

  def http_request(method, uri, options = {}, &block)
    uri = Addressable::URI.heuristic_parse(uri)
    c = options.fetch(:client) { HTTPClient.new }
    c.ssl_config.verify_mode = OpenSSL::SSL::VERIFY_NONE
    c.reset_all
    if options[:basic_auth]
      c.force_basic_auth = true
      c.set_basic_auth(nil, options[:basic_auth][0], options[:basic_auth][1])
    end
    params = [method, uri.normalize.to_s,
      WebMock::Util::QueryMapper.query_to_values(uri.query, notation: WebMock::Config.instance.query_values_notation), options[:body], options[:headers] || {}]
    if HTTPClientSpecHelper.async_mode
      connection = c.request_async(*params)
      connection.join
      response = connection.pop
    else
      response = c.request(*params, &block)
    end
    headers = merge_headers(response)
    OpenStruct.new({
      body: HTTPClientSpecHelper.async_mode ? response.content.read : response.content,
      headers: headers,
      status: response.code.to_s,
      message: response.reason
    })
  end

  def client_timeout_exception_class
    HTTPClient::TimeoutError
  end

  def connection_refused_exception_class
    Errno::ECONNREFUSED
  end

  def http_library
    :httpclient
  end

private

  def merge_headers(response)
    response.header.all.inject({}) do |headers, header|
      if !headers.has_key?(header[0])
        headers[header[0]] = header[1]
      else
        headers[header[0]] = [headers[header[0]], header[1]].join(', ')
      end
      headers
    end
  end
end
