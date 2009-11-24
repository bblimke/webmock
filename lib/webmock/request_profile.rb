module WebMock

  class RequestProfile < Struct.new(:method, :uri, :body, :headers)

    def initialize(method, uri, body = nil, headers = nil)
      super
      self.uri = WebMock::Util::URI.normalize_uri(self.uri) unless self.uri.is_a?(Addressable::URI)
      self.headers = WebMock::Util::Headers.normalize_headers(self.headers)
    end

    def with(options)
      self.body = options[:body] if options.has_key?(:body)
      self.headers = WebMock::Util::Headers.normalize_headers(options[:headers]) if options.has_key?(:headers)
      self
    end

    def to_s
      string = "#{self.method.to_s.upcase} #{WebMock::Util::URI.strip_default_port_from_uri_string(self.uri.to_s)}"
      string << " with body '#{body}'" if body
      if headers && !headers.empty?
        string << " with headers #{WebMock::Util::Headers.normalize_headers(headers).inspect.gsub("\"","'")}"
      end
      string
    end

  end

end
