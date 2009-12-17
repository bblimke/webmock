module WebMock

  class Request
    attr_accessor :method, :uri, :body, :headers, :with_block

    def initialize(method, uri, options = {})
      self.method = method
      self.uri = uri.is_a?(Addressable::URI) ? uri : WebMock::Util::URI.normalize_uri(uri)
      assign_options(options)
    end

    def to_s
      string = "#{self.method.to_s.upcase} #{WebMock::Util::URI.strip_default_port_from_uri_string(self.uri.to_s)}"
      string << " with body '#{body.to_s}'" if body && body.to_s != ''
      if headers && !headers.empty?
        string << " with headers #{WebMock::Util::Headers.normalize_headers(headers).inspect.gsub("\"","'")}"
      end      
      string << " with given block" if with_block
      string
    end

    private

    def assign_options(options)
      self.body = options[:body] if options.has_key?(:body)
      self.headers = WebMock::Util::Headers.normalize_headers(options[:headers]) if options.has_key?(:headers)
    end

  end
end
