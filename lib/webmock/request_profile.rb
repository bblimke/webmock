module WebMock

  class RequestProfile < Struct.new(:method, :uri, :body, :headers)

    def initialize(method, uri, options = {})
      self.method = method
      self.uri = uri.is_a?(Addressable::URI) ? uri : WebMock::Util::URI.normalize_uri(uri)
      assign_options(options)
    end

    def with(options)
      assign_options(options)
      self
    end

    def to_s
      string = "#{self.method.to_s.upcase} #{WebMock::Util::URI.strip_default_port_from_uri_string(self.uri.to_s)}"
      string << " with body '#{body.to_s}'" if body && !body.is_empty?
      if headers && !headers.empty?
        string << " with headers #{WebMock::Util::Headers.normalize_headers(headers).inspect.gsub("\"","'")}"
      end
      string
    end
    
    private 
    
    def assign_options(options)
      self.body = Body.new(options[:body]) if options.has_key?(:body)
      self.headers = WebMock::Util::Headers.normalize_headers(options[:headers]) if options.has_key?(:headers)
    end
    

    class Body

      attr_reader :data

      def initialize(data)
        @data = data
      end

      def ==(other)
        other.is_a?(Body) &&
          (other.is_empty? && self.is_empty? || other.data == self.data)
      end

      def is_empty?
        @data.nil? || @data == ""
      end

      def to_s
        @data
      end

    end

  end

end
