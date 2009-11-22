module WebMock

  class RequestProfile < Struct.new(:method, :uri, :body, :headers)
    
    def initialize(method, uri, body = nil, headers = nil)
      super
      self.uri = WebMock::URL.normalize_uri(self.uri) unless self.uri.is_a?(Addressable::URI)
      self.headers = Utility.normalize_headers(self.headers)
    end

    def with(options)
      self.body = options[:body] if options.has_key?(:body)
      self.headers = Utility.normalize_headers(options[:headers]) if options.has_key?(:headers)
      self
    end

    #self needs to be a subset of other. Other needs to be more general.
    def match(other)
      match_method(other) &&
      match_body(other) &&
      match_headers(other) &&
      match_url(other)
    end

    def to_s
      string = "#{self.method.to_s.upcase} #{self.uri}"
      string << " with body '#{body}'" if body
      if headers && !headers.empty?
        string << " with headers #{WebMock::Utility.normalize_headers(headers).inspect.gsub("\"","'")}"
      end
      string
    end

    private

    def match_url(other)
      raise "Can't match regexp request profile" if self.uri.is_a?(Regexp)
      if other.uri.is_a?(Addressable::URI)
        URL.normalize_uri(uri) === URL.normalize_uri(other.uri)
      elsif other.uri.is_a?(Regexp)
        WebMock::URL.variations_of_uri_as_strings(self.uri).any? { |u| u.match(other.uri) }
      else
        false
      end
    end

    def match_headers(other)
      return false if self.headers && !self.headers.empty? && other.headers && other.headers.empty?
      if other.headers && !other.headers.empty?
        other.headers.each do | key, value |
          return false unless (self.headers && self.headers.has_key?(key) && value == self.headers[key])
        end
      end
      return true
    end

    def match_body(other)
      other.body == self.body || other.body.nil?
    end

    def match_method(other)
      other.method == self.method || other.method == :any
    end
  end

end
