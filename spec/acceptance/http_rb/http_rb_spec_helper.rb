require "ostruct"

module HttpRbSpecHelper
  def http_request(method, uri, options = {})
    response = HTTP.request(method, normalize_uri(uri), options)

    OpenStruct.new({
      :body       => response.body.to_s,
      :headers    => normalize_headers(response.headers.to_h),
      :status     => response.code.to_s,
      :message    => response.reason
    })
  end

  def client_timeout_exception_class
    return Errno::ETIMEDOUT if HTTP::VERSION < "1.0.0"
    HTTP::ConnectionError
  end

  def connection_refused_exception_class
    return Errno::ECONNREFUSED if HTTP::VERSION < "1.0.0"
    HTTP::ConnectionError
  end

  def http_library
    :http_rb
  end

  def normalize_uri(uri)
    Addressable::URI.heuristic_parse(uri).normalize.to_s
  end

  def normalize_headers(headers)
    headers = Hash[headers.map { |k, v| [k, Array(v).join(", ")] }]
    WebMock::Util::Headers.normalize_headers headers
  end

  def stub_simple_request(host, status = 200, headers = {}, body = nil)
    stub_request(:any, host).to_return({
      :status   => status,
      :headers  => headers.merge({ "Host" => host }),
      :body     => body
    })
  end
end
