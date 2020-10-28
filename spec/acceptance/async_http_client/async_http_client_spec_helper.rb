module AsyncHttpClientSpecHelper
  def http_request(method, url, options = {}, &block)
    endpoint = Async::HTTP::Endpoint.parse(url)

    path = endpoint.path
    path = path + "?" + options[:query] if options[:query]

    headers = (options[:headers] || {}).each_with_object([]) do |(k, v), o|
      Array(v).each do |v|
        o.push [k, v]
      end
    end
    headers.push(
      ['authorization', 'Basic ' + Base64.strict_encode64(options[:basic_auth].join(':'))]
    ) if options[:basic_auth]

    body = options[:body]

    Async do
      begin
        Async::HTTP::Client.open(endpoint) do |client|
          response = client.send(
            method,
            path,
            headers,
            body
          )

          OpenStruct.new(
            build_hash_response(response)
          )
        end
      rescue Exception => e
        e
      end
    end.wait
  end

  def client_timeout_exception_class
    Async::TimeoutError
  end

  def connection_refused_exception_class
    Errno::ECONNREFUSED
  end

  def http_library
    :async_http_client
  end

  private

  def build_hash_response(response)
    {

      status: response.status.to_s,
      message: Protocol::HTTP1::Reason::DESCRIPTIONS[response.status],
      headers: build_response_headers(response),
      body: response.read
    }
  end

  def build_response_headers(response)
    response.headers.each.each_with_object({}) do |(k, v), o|
      o[k] ||= []
      o[k] << v
    end.tap do |o|
      o.each do |k, v|
        o[k] = v.join(', ')
      end
    end
  end
end
