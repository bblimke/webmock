module ManticoreSpecHelper
  def http_request(method, uri, options = {})
    client = Manticore::Client.new

    if basic_auth = options[:basic_auth]
      options = options.merge(auth: {user: basic_auth[0], pass: basic_auth[1]})
    end

    response = client.http(method, uri, options)
    OpenStruct.new({
      body: response.body || '',
      headers: WebMock::Util::Headers.normalize_headers(join_array_values(response.headers)),
      status: response.code.to_s
    })
  end

  def join_array_values(hash)
    hash.reduce({}) do |h, (k,v)|
      v = v.join(', ') if v.is_a?(Array)
      h.merge(k => v)
    end
  end

  def client_timeout_exception_class
    Manticore::ConnectTimeout
  end

  def connection_refused_exception_class
    Manticore::SocketException
  end

  def http_library
    :manticore
  end
end
