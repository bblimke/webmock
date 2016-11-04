module NetHTTPSpecHelper
  def http_request(method, uri, options = {}, &block)
    begin
      uri = URI.parse(uri)
    rescue
      uri = Addressable::URI.heuristic_parse(uri)
    end
    response = nil
    clazz = Net::HTTP.const_get("#{method.to_s.capitalize}")
    req = clazz.new("#{uri.path}#{uri.query ? '?' : ''}#{uri.query}", nil)
    options[:headers].each do |k,v|
      if v.is_a?(Array)
        v.each_with_index do |e,i|
          i == 0 ? (req[k] = e) : req.add_field(k, e)
        end
      else
        req[k] = v
      end
    end if options[:headers]

    if options[:basic_auth]
      req.basic_auth(options[:basic_auth][0], options[:basic_auth][1])
    end

    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == "https"
      http.use_ssl = true
      #1.9.1 has a bug with ssl_timeout
      http.ssl_timeout = 20 unless RUBY_PLATFORM =~ /java/
      http.open_timeout = 60
      http.read_timeout = 60
    end
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    response = http.start {|open_http|
      open_http.request(req, options[:body], &block)
    }
    headers = {}
    response.each_header {|name, value| headers[name] = value}
    OpenStruct.new({
      body: response.body,
      headers: WebMock::Util::Headers.normalize_headers(headers),
      status: response.code,
      message: response.message
    })
  end

  def client_timeout_exception_class
    if defined?(Net::OpenTimeout)
      Net::OpenTimeout
    elsif defined?(Net::HTTP::OpenTimeout)
      Net::HTTP::OpenTimeout
    else
      Timeout::Error
    end
  end

  def connection_refused_exception_class
    Errno::ECONNREFUSED
  end

  def http_library
    :net_http
  end
end
