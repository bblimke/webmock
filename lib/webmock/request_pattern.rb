module WebMock

  module RSpecMatcherDetector
    def rSpecHashIncludingMatcher?(matcher)
      matcher.class.name =~ /R?Spec::Mocks::ArgumentMatchers::HashIncludingMatcher/
    end
  end

  class RequestPattern

    attr_reader :method_pattern, :uri_pattern, :body_pattern, :headers_pattern

    def initialize(method, uri, options = {})
      @method_pattern  = MethodPattern.new(method)
      @uri_pattern     = create_uri_pattern(uri)
      @body_pattern    = nil
      @headers_pattern = nil
      @with_block      = nil
      assign_options(options)
    end

    def with(options = {}, &block)
      raise ArgumentError.new('#with method invoked with no arguments. Either options hash or block must be specified.') if options.empty? && !block_given?
      assign_options(options)
      @with_block = block
      self
    end

    def matches?(request_signature)
      content_type = request_signature.headers['Content-Type'] if request_signature.headers
      content_type = content_type.split(';').first if content_type
      @method_pattern.matches?(request_signature.method) &&
        @uri_pattern.matches?(request_signature.uri) &&
        (@body_pattern.nil? || @body_pattern.matches?(request_signature.body, content_type || "")) &&
        (@headers_pattern.nil? || @headers_pattern.matches?(request_signature.headers)) &&
        (@with_block.nil? || @with_block.call(request_signature))
    end

    def to_s
      string = "#{@method_pattern.to_s.upcase}"
      string << " #{@uri_pattern.to_s}"
      string << " with body #{@body_pattern.to_s}" if @body_pattern
      string << " with headers #{@headers_pattern.to_s}" if @headers_pattern
      string << " with given block" if @with_block
      string
    end

    private


    def assign_options(options)
      options = WebMock::Util::HashKeysStringifier.stringify_keys!(options, :deep => true)
      HashValidator.new(options).validate_keys('body', 'headers', 'query')
      @body_pattern = BodyPattern.new(options['body']) if options.has_key?('body')
      @headers_pattern = HeadersPattern.new(options['headers']) if options.has_key?('headers')
      @uri_pattern.add_query_params(options['query']) if options.has_key?('query')
    end

    def create_uri_pattern(uri)
      if uri.is_a?(Regexp)
        URIRegexpPattern.new(uri)
      elsif uri.is_a?(Addressable::Template)
        URIAddressablePattern.new(uri)
      else
        URIStringPattern.new(uri)
      end
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
    include RSpecMatcherDetector

    def initialize(pattern)
      @pattern = case pattern
      when Addressable::URI, Addressable::Template
        pattern
      else
          WebMock::Util::URI.normalize_uri(pattern)
      end
      @query_params = nil
    end

    def add_query_params(query_params)
      @query_params = if query_params.is_a?(Hash)
        query_params
      elsif query_params.is_a?(WebMock::Matchers::HashIncludingMatcher)
        query_params
      elsif rSpecHashIncludingMatcher?(query_params)
        WebMock::Matchers::HashIncludingMatcher.from_rspec_matcher(query_params)
      else
        WebMock::Util::QueryMapper.query_to_values(query_params, :notation => Config.instance.query_values_notation)
      end
    end

    def to_s
      str = @pattern.inspect
      str += " with query params #{@query_params.inspect}" if @query_params
      str
    end
  end

  class URIRegexpPattern  < URIPattern
    def matches?(uri)
      WebMock::Util::URI.variations_of_uri_as_strings(uri).any? { |u| u.match(@pattern) } &&
        (@query_params.nil? || @query_params == WebMock::Util::QueryMapper.query_to_values(uri.query, :notation => Config.instance.query_values_notation))
    end

    def to_s
      str = @pattern.inspect
      str += " with query params #{@query_params.inspect}" if @query_params
      str
    end
  end

  class URIAddressablePattern  < URIPattern
    def matches?(uri)
      if @query_params.nil?
        # Let Addressable check the whole URI
        WebMock::Util::URI.variations_of_uri_as_strings(uri).any? { |u| @pattern.match(u) }
      else
        # WebMock checks the query, Addressable checks everything else
        WebMock::Util::URI.variations_of_uri_as_strings(uri.omit(:query)).any? { |u| @pattern.match(u) } &&
          @query_params == WebMock::Util::QueryMapper.query_to_values(uri.query)
      end
    end

    def add_query_params(query_params)
      warn "WebMock warning: ignoring query params in RFC 6570 template and checking them with WebMock"
      super(query_params)
    end

    def to_s
      str = @pattern.pattern.inspect
      str += " with variables #{@pattern.variables.inspect}" if @pattern.variables
      str
    end
  end

  class URIStringPattern < URIPattern
    def matches?(uri)
      if @pattern.is_a?(Addressable::URI)
        if @query_params
          uri.omit(:query) === @pattern &&
          (@query_params.nil? || @query_params == WebMock::Util::QueryMapper.query_to_values(uri.query, :notation => Config.instance.query_values_notation))
        else
          uri === @pattern
        end
      else
        false
      end
    end

    def add_query_params(query_params)
      super
      if @query_params.is_a?(Hash) || @query_params.is_a?(String)
        query_hash = (WebMock::Util::QueryMapper.query_to_values(@pattern.query, :notation => Config.instance.query_values_notation) || {}).merge(@query_params)
        @pattern.query = WebMock::Util::QueryMapper.values_to_query(query_hash, :notation => WebMock::Config.instance.query_values_notation)
        @query_params = nil
      end
    end

    def to_s
      str = WebMock::Util::URI.strip_default_port_from_uri_string(@pattern.to_s)
      str += " with query params #{@query_params.inspect}" if @query_params
      str
    end
  end


  class BodyPattern
    include RSpecMatcherDetector

    BODY_FORMATS = {
      'text/xml'               => :xml,
      'application/xml'        => :xml,
      'application/json'       => :json,
      'text/json'              => :json,
      'application/javascript' => :json,
      'text/javascript'        => :json,
      'text/html'              => :html,
      'application/x-yaml'     => :yaml,
      'text/yaml'              => :yaml,
      'text/plain'             => :plain
    }

    attr_reader :pattern

    def initialize(pattern)
      @pattern = if pattern.is_a?(Hash)
        normalize_hash(pattern)
      elsif rSpecHashIncludingMatcher?(pattern)
        WebMock::Matchers::HashIncludingMatcher.from_rspec_matcher(pattern)
      else
        pattern
      end
    end

    def matches?(body, content_type = "")
      if (@pattern).is_a?(Hash)
        return true if @pattern.empty?
        matching_hashes?(body_as_hash(body, content_type), @pattern)
      elsif (@pattern).is_a?(WebMock::Matchers::HashIncludingMatcher)
        @pattern == body_as_hash(body, content_type)
      else
        empty_string?(@pattern) && empty_string?(body) ||
          @pattern == body ||
          @pattern === body
      end
    end

    def to_s
      @pattern.inspect
    end

    private
    def body_as_hash(body, content_type)
      case BODY_FORMATS[content_type]
      when :json then
        WebMock::Util::JSON.parse(body)
      when :xml then
        Crack::XML.parse(body)
      else
        WebMock::Util::QueryMapper.query_to_values(body, :notation => Config.instance.query_values_notation)
      end
    end

    # Compare two hashes for equality
    #
    # For two hashes to match they must have the same length and all
    # values must match when compared using `#===`.
    #
    # The following hashes are examples of matches:
    #
    #     {a: /\d+/} and {a: '123'}
    #
    #     {a: '123'} and {a: '123'}
    #
    #     {a: {b: /\d+/}} and {a: {b: '123'}}
    #
    #     {a: {b: 'wow'}} and {a: {b: 'wow'}}
    #
    # @param [Hash] query_parameters typically the result of parsing
    #   JSON, XML or URL encoded parameters.
    #
    # @param [Hash] pattern which contains keys with a string, hash or
    #   regular expression value to use for comparison.
    #
    # @return [Boolean] true if the paramaters match the comparison
    #   hash, false if not.
    def matching_hashes?(query_parameters, pattern)
      return false unless query_parameters.is_a?(Hash)
      return false unless query_parameters.keys.sort == pattern.keys.sort
      query_parameters.each do |key, actual|
        expected = pattern[key]

        if actual.is_a?(Hash) && expected.is_a?(Hash)
          return false unless matching_hashes?(actual, expected)
        else
          return false unless expected === actual
        end
      end
      true
    end

    def empty_string?(string)
      string.nil? || string == ""
    end

    def normalize_hash(hash)
      Hash[WebMock::Util::HashKeysStringifier.stringify_keys!(hash, :deep => true).sort]
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
