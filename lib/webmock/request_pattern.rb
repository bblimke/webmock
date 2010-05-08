module WebMock

  class RequestPattern

    def initialize(method, uri, options = {})
      @method_pattern = MethodPattern.new(method)
      @uri_pattern = URIPattern.new(uri)
      assign_options(options)
    end

    def with(options = {}, &block)
      assign_options(options)
      @with_block = block
      self
    end

    def matches?(request_signature)
      @method_pattern.matches?(request_signature.method) &&
      @uri_pattern.matches?(request_signature.uri) &&
      (@body_pattern.nil? || @body_pattern.matches?(request_signature.body)) &&
      (@headers_pattern.nil? || @headers_pattern.matches?(request_signature.headers)) &&
      (@with_block.nil? || @with_block.call(request_signature))
    end

    def to_s
      string = "#{@method_pattern.to_s.upcase}"
      string << " #{@uri_pattern.to_s}"
      string << " with body '#{@body_pattern.to_s}'" if @body_pattern
      string << " with headers #{@headers_pattern.to_s}" if @headers_pattern
      string << " with given block" if @with_block
      string
    end

    private


    def assign_options(options)
      @body_pattern = BodyPattern.new(options[:body]) if options.has_key?(:body)
      @headers_pattern = HeadersPattern.new(options[:headers]) if options.has_key?(:headers)
    end

  end
  

  class MethodPattern
    def initialize(pattern)
      @pattern = pattern
    end

    def matches?(method)
      @pattern == method || @pattern == :any
    end

    def to_s
      @pattern.to_s
    end
  end

  class URIPattern
    def initialize(pattern)
      @pattern = pattern.is_a?(Addressable::URI) ? pattern : WebMock::Util::URI.normalize_uri(pattern)
    end

    def matches?(uri)
      if @pattern.is_a?(Addressable::URI)
        ##TODO : do I need to normalize again??
        uri === @pattern
      elsif @pattern.is_a?(Regexp)
        WebMock::Util::URI.variations_of_uri_as_strings(uri).any? { |u| u.match(@pattern) }
      else
        false
      end
    end

    def to_s
      WebMock::Util::URI.strip_default_port_from_uri_string(@pattern.to_s)
    end
  end

  class BodyPattern
    def initialize(pattern)
      @pattern = pattern
    end

    def matches?(uri)
      empty_string?(@pattern) && empty_string?(uri) ||
        @pattern == uri ||
        @pattern === uri
    end
    
    def to_s
      @pattern.to_s
    end

    private

    def empty_string?(string)
      string.nil? || string == ""
    end
  end

  class HeadersPattern
    def initialize(pattern)
      @pattern = WebMock::Util::Headers.normalize_headers(pattern) || {}
    end

    def matches?(headers)
      if empty_headers?(@pattern)
        empty_headers?(headers)
      else
        return false if empty_headers?(headers)
        @pattern.each do |key, value|
          return false unless headers.has_key?(key) && value === headers[key]
        end
        true
      end
    end
    
    def to_s
      WebMock::Util::Headers.sorted_headers_string(@pattern)
    end

    private

    def empty_headers?(headers)
      headers.nil? || headers == {}
    end
  end

end
