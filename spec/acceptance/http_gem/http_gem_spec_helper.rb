require "ostruct"


module HttpGemSpecHelper

  def http_request(method, uri, options = {}, &block)
    response = HTTP.request(method, normalize_uri(uri), options).response

    OpenStruct.new({
      :body       => response.body,
      :headers    => normalize_headers(response.headers),
      :status     => response.status.to_s,
      :message    => response.reason
    })
  end


  def normalize_uri(uri)
    Addressable::URI.heuristic_parse(uri).normalize.to_s
  end


  def normalize_headers headers
    WebMock::Util::Headers.normalize_headers(Hash[headers.map { |k, v|
      [k, v.is_a?(Array) ? v.join(", ") : v]
    }])
  end


  def stub_simple_request host, status = 200, headers = {}
    stub_request(:any, host).to_return({
      :status   => status,
      :headers  => headers.merge({ "Host" => host })
    })
  end


  def client_timeout_exception_class
    Errno::ETIMEDOUT
  end


  def connection_refused_exception_class
    Errno::ECONNREFUSED
  end


  def http_library
    :http_gem
  end

end
