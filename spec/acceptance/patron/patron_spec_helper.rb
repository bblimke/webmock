require 'ostruct'

module PatronSpecHelper
  def http_request(method, uri, options = {}, &block)
    method = method.to_sym
    uri = Addressable::URI.heuristic_parse(uri)
    sess = Patron::Session.new
    sess.base_url = "#{uri.omit(:path, :query).normalize.to_s}".gsub(/\/$/,"")

    if options[:basic_auth]
      sess.username = options[:basic_auth][0]
      sess.password = options[:basic_auth][1]
    end

    sess.connect_timeout = 30
    sess.timeout = 30
    sess.max_redirects = 0
    uri = "#{uri.path}#{uri.query ? '?' : ''}#{uri.query}"
    uri = uri.gsub(' ','%20')
    response = sess.request(method, uri, options[:headers] || {}, {
      data: options[:body]
    })
    headers = {}
    if response.headers
      response.headers.each do |k,v|
        v = v.join(", ") if v.is_a?(Array)
        headers[k] = v
      end
    end

    status_line_pattern = %r(\AHTTP/(\d+(\.\d+)?)\s+(\d\d\d)\s*([^\r\n]+)?)
    message = response.status_line.match(status_line_pattern)[4] || ""

    OpenStruct.new({
      body: response.body,
      headers: WebMock::Util::Headers.normalize_headers(headers),
      status: response.status.to_s,
      message: message
    })
  end

  def client_timeout_exception_class
    Patron::TimeoutError
  end

  def connection_refused_exception_class
    Patron::ConnectionFailed
  end

  def http_library
    :patron
  end

end
