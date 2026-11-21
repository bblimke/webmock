# frozen_string_literal: true

module WebMock

  module RSpecMatcherDetector
    extend self

    def rSpecHashIncludingMatcher?(matcher)
      rspec_argument_matcher_name(matcher) =~ /R?Spec::Mocks::ArgumentMatchers::HashIncludingMatcher/
    end

    def rSpecHashExcludingMatcher?(matcher)
      rspec_argument_matcher_name(matcher) =~ /R?Spec::Mocks::ArgumentMatchers::HashExcludingMatcher/
    end

    def rSpecAnyArgMatcher?(matcher)
      rspec_argument_matcher_name(matcher) =~ /R?Spec::Mocks::ArgumentMatchers::AnyArgMatcher/
    end

    def rSpecHashMatcher?(matcher)
      rspec_argument_matcher_name(matcher) =~ /R?Spec::Mocks::ArgumentMatchers::Hash(In|Ex)cludingMatcher/
    end

    def rSpecArrayMatcher?(matcher)
      rspec_argument_matcher_name(matcher) =~ /R?Spec::Mocks::ArgumentMatchers::Array(In|Ex)cludingMatcher/
    end

    # The class name of a possible RSpec matcher, or nil for values that
    # can't be one, which are most values in a pattern. A custom matcher can
    # be a BasicObject, which has no #class.
    def rspec_argument_matcher_name(matcher)
      case matcher
      when String, Symbol, Numeric, Regexp, Hash, Array, nil, true, false then nil
      when ::Object then matcher.class.name
      end
    end

    # Turns RSpec's hash_including or hash_excluding into WebMock's matcher,
    # which compares string keys. Returns anything else as it is.
    def webmock_hash_matcher(matcher)
      if rSpecHashIncludingMatcher?(matcher)
        WebMock::Matchers::HashIncludingMatcher.from_rspec_matcher(matcher)
      elsif rSpecHashExcludingMatcher?(matcher)
        WebMock::Matchers::HashExcludingMatcher.from_rspec_matcher(matcher)
      else
        matcher
      end
    end
  end

  class RequestPattern

    attr_reader :method_pattern, :uri_pattern, :body_pattern, :headers_pattern, :with_block

    # History uses an opaque key so it needn't retain a matcher block or
    # an upload captured by that block. Changing the pattern replaces the key.
    attr_reader :match_token

    def initialize(method, uri, options = {})
      @method_pattern  = MethodPattern.new(method)
      @uri_pattern     = create_uri_pattern(uri)
      @body_pattern    = nil
      @headers_pattern = nil
      @with_block      = nil
      assign_options(options)
      @match_token = Object.new if @body_pattern
    end

    def with(options = {}, &block)
      raise ArgumentError.new('#with method invoked with no arguments. Either options hash or block must be specified. Created a block with do..end? Try creating it with curly braces {} instead.') if options.empty? && !block_given?
      assign_options(options)
      # A later call with options only keeps the block given earlier.
      @with_block = block if block
      @match_token = (@body_pattern || @with_block) && Object.new
      self
    end

    def matches?(request_signature)
      return false unless @method_pattern.matches?(request_signature.method) && @uri_pattern.matches?(request_signature.uri)

      token = @match_token
      matched = (@body_pattern.nil? || body_matches?(request_signature)) &&
        (@headers_pattern.nil? || @headers_pattern.matches?(request_signature.headers)) &&
        (@with_block.nil? || @with_block.call(request_signature))
      yield(token, matched) if token && block_given?
      matched
    end

    def to_s
      string = "#{@method_pattern.to_s.upcase}".dup
      string << " #{@uri_pattern.to_s}"
      string << " with body #{@body_pattern.to_s}" if @body_pattern
      string << " with headers #{@headers_pattern.to_s}" if @headers_pattern
      string << " with given block" if @with_block
      string
    end

    private

    def body_matches?(request)
      serialized_body = request.serialized_body if request.respond_to?(:serialized_body)
      @body_pattern.matches?(request.body, request.content_type, serialized_body)
    end

    def assign_options(options)
      options = WebMock::Util::HashKeysStringifier.stringify_keys!(options, deep: true)
      HashValidator.new(options).validate_keys('body', 'headers', 'query', 'basic_auth')
      set_basic_auth_as_headers!(options)
      @body_pattern = BodyPattern.new(options['body']) if options.has_key?('body')
      @headers_pattern = HeadersPattern.new(options['headers']) if options.has_key?('headers')
      @uri_pattern.add_query_params(options['query']) if options.has_key?('query')
    end

    def set_basic_auth_as_headers!(options)
      if basic_auth = options.delete('basic_auth')
        validate_basic_auth!(basic_auth)
        options['headers'] ||= {}
        options['headers']['Authorization'] = WebMock::Util::Headers.basic_auth_header(basic_auth[0],basic_auth[1])
      end
    end

    def validate_basic_auth!(basic_auth)
      if !basic_auth.is_a?(Array) || basic_auth.map{|e| e.is_a?(String)}.uniq != [true]
        raise "The basic_auth option value should be an array which contains 2 strings: username and password"
      end
    end

    def create_uri_pattern(uri)
      if uri.is_a?(Regexp)
        URIRegexpPattern.new(uri)
      elsif uri.is_a?(Addressable::Template)
        URIAddressablePattern.new(uri)
      elsif uri.respond_to?(:call)
        URICallablePattern.new(uri)
      elsif uri.is_a?(::URI::Generic)
        URIStringPattern.new(uri.to_s)
      elsif uri.respond_to?(:to_str)
        URIStringPattern.new(uri.to_str)
      else
        raise ArgumentError.new("URI should be a String, Regexp, Addressable::Template, a callable object, or respond to #to_str. Got: #{uri.class}")
      end
    end
  end


  class MethodPattern
    # Request signatures store the method as a lower case Symbol, so a method
    # given as a String or in upper case, like "get" or :GET, matches too.
    # Anything else, such as nil, is kept as given and never matches.
    def initialize(pattern)
      @pattern = pattern.respond_to?(:to_sym) ? pattern.to_sym.downcase : pattern
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
      @pattern = if pattern.is_a?(Addressable::URI) \
                    || pattern.is_a?(Addressable::Template)
        pattern
      elsif pattern.respond_to?(:call)
        pattern
      else
        WebMock::Util::URI.normalize_uri(pattern)
      end
      @query_params = nil
    end

    def add_query_params(query_params)
      query_params = webmock_hash_matcher(query_params)
      @query_params = if query_params.is_a?(Hash) \
              || query_params.is_a?(WebMock::Matchers::HashIncludingMatcher) \
              || query_params.is_a?(WebMock::Matchers::HashExcludingMatcher)
        # Query values are always strings, so expected values such as 1 or
        # true are compared as "1" and "true", in nested matchers too.
        WebMock::Util::ValuesStringifier.stringify_query_values(query_params)
      elsif query_params.equal?(:any) \
              || query_params.is_a?(WebMock::Matchers::AnyArgMatcher) \
              || rSpecAnyArgMatcher?(query_params)
        WebMock::Matchers::AnyArgMatcher.new(nil)
      elsif query_params.nil? || query_params.is_a?(String)
        sorted_query_values(WebMock::Util::QueryMapper.query_to_values(query_params, notation: Config.instance.query_values_notation))
      else
        raise ArgumentError, "Query should be a String, Hash, :any, nil, or a hash_including or hash_excluding matcher. Got: #{query_params.class}"
      end
    end

    def matches?(uri)
      pattern_matches?(uri) && query_params_matches?(uri)
    end

    def to_s
      str = pattern_inspect
      str += " with query params #{@query_params.inspect}" if @query_params
      str
    end

    # Ruby source for the URI argument of stub_request, for snippets.
    def to_snippet
      pattern_inspect
    end

    # Ruby source for the query option of with, for snippets, or nil.
    def query_snippet
      case @query_params
      when nil then nil
      when WebMock::Matchers::AnyArgMatcher then ":any"
      # Pairs of the :flat_array notation, which a query string describes
      when Array then WebMock::Util::QueryMapper.values_to_query(@query_params, notation: :flat_array).inspect
      else @query_params.inspect
      end
    end

    private

    def raise_any_query_with_uri_query
      raise ArgumentError, "query: :any can't be combined with a query in the URI #{pattern_inspect}, because no request would match. Remove the query from the URI."
    end

    def pattern_inspect
      @pattern.inspect
    end

    def query_params_matches?(uri)
      return true if @query_params.nil?

      actual = WebMock::Util::QueryMapper.query_to_values(uri.query, notation: Config.instance.query_values_notation)
      actual = sorted_query_values(actual) if @query_params.is_a?(Array)
      @query_params == actual
    end

    # With :flat_array the values are pairs in the order given, so both
    # sides are sorted, as the queries of normalized URIs are. Adapters
    # pass normalized URIs, but a signature can be given any URI.
    def sorted_query_values(values)
      values.is_a?(Array) ? WebMock::Util::URI.sort_query_values(values) : values
    end
  end

  class URICallablePattern  < URIPattern
    # A lambda can't be written as Ruby source, so it is shown in quotes, as
    # before.
    def to_snippet
      "\"#{pattern_inspect}\""
    end

    private

    def pattern_matches?(uri)
      @pattern.call(uri)
    end
  end

  class URIRegexpPattern  < URIPattern
    private

    def pattern_matches?(uri)
      WebMock::Util::URI.variations_of_uri_as_strings(uri).any? { |u| u.match(@pattern) }
    end
  end

  class URIAddressablePattern  < URIPattern
    def add_query_params(query_params)
      super(query_params)
      # With query params, the template is matched against the URI without its
      # query, so a literal query in the template can never match.
      if @query_params.is_a?(WebMock::Matchers::AnyArgMatcher) && @pattern.pattern.gsub(/\{[^}]*\}/, '').include?('?')
        raise_any_query_with_uri_query
      end
      @@add_query_params_warned ||= false
      if not @@add_query_params_warned
        @@add_query_params_warned = true
        warn "WebMock warning: ignoring query params in RFC 6570 template and checking them with WebMock"
      end
    end

    def to_snippet
      "Addressable::Template.new(#{pattern_inspect})"
    end

    private

    def pattern_matches?(uri)
      if @query_params.nil?
        # Let Addressable check the whole URI
        matches_with_variations?(uri)
      else
        # WebMock checks the query, Addressable checks everything else
        matches_with_variations?(uri.omit(:query))
      end
    end

    def pattern_inspect
      @pattern.pattern.inspect
    end

    def matches_with_variations?(uri)
      template =
        begin
          Addressable::Template.new(WebMock::Util::URI.heuristic_parse(@pattern.pattern))
        rescue Addressable::URI::InvalidURIError
          Addressable::Template.new(@pattern.pattern)
        end
      variations = WebMock::Util::URI.variations_of_uri_as_strings(uri)
      # Normalized URIs decode reserved characters such as ":", "/" and "=" in
      # the query, while RFC 6570 query expansion expects them encoded. The
      # strict variations keep the path as normalized, since decoding it
      # could turn an encoded "/" or "?" into a different path.
      # Encoding can only change a query with other characters than these,
      # or with a second "=" in a pair.
      strict_query = uri.query && uri.query.match?(/[^A-Za-z0-9\-._~%=&]|=[^&]*=/) && strictly_encoded_query(uri.query)
      if strict_query && strict_query != uri.query
        suffix = "?#{strict_query}#{"##{uri.fragment}" if uri.fragment}"
        base = uri.omit(:query, :fragment)
        bases = [base]
        bases << base.omit(:port) if base.port == Addressable::URI.port_mapping[base.scheme]
        variations = (variations + bases.map { |b| "#{b}#{suffix}" }).uniq
      end
      variations.any? { |u|
        template_matches_uri?(template, u)
      }
    end

    def strictly_encoded_query(query)
      query.split("&").map { |pair|
        pair.split("=", 2).map { |part|
          Addressable::URI.encode_component(
            Addressable::URI.unencode_component(part),
            Addressable::URI::CharacterClasses::UNRESERVED
          )
        }.join("=")
      }.join("&")
    end

    def template_matches_uri?(template, uri)
      template.match(uri)
    rescue Addressable::URI::InvalidURIError
      false
    end
  end

  class URIStringPattern < URIPattern
    def add_query_params(query_params)
      # A query hash with a matcher, kept from an earlier call.
      earlier = @query_params if @query_params.is_a?(Hash)
      super
      if @query_params.is_a?(Hash) || @query_params.is_a?(String)
        query_hash = (WebMock::Util::QueryMapper.query_to_values(@pattern.query, notation: Config.instance.query_values_notation) || {}).merge(earlier || {}).merge(@query_params)
        if WebMock::Util::ValuesStringifier.includes_query_matcher?(query_hash)
          # A matcher can't be written into the URI, so the whole query is
          # compared on its own.
          @pattern.query = nil
          @query_params = query_hash
        else
          @pattern.query = WebMock::Util::QueryMapper.values_to_query(query_hash, notation: WebMock::Config.instance.query_values_notation)
          @query_params = nil
        end
      elsif @query_params.is_a?(WebMock::Matchers::AnyArgMatcher) && (@pattern.query || earlier)
        # The URI is then compared without its query, so it could never match.
        raise_any_query_with_uri_query
      end
    end

    def to_snippet
      "\"#{pattern_inspect}\""
    end

    private

    def pattern_matches?(uri)
      if @pattern.is_a?(Addressable::URI)
        if @query_params
          uri.omit(:query) === @pattern
        else
          uri === @pattern
        end
      else
        false
      end
    end

    def pattern_inspect
      WebMock::Util::URI.strip_default_port_from_uri_string(@pattern.to_s)
    end
  end


  class BodyPattern
    include RSpecMatcherDetector

    # A String body that isn't valid UTF-8, such as an uploaded file, can't
    # be a URL encoded form, so it isn't parsed as one.
    def self.form_parseable?(body)
      return true unless body.is_a?(String)
      return true if body.ascii_only?

      body = body.dup.force_encoding(Encoding::UTF_8) unless body.encoding == Encoding::UTF_8
      body.valid_encoding?
    end

    # Kept so existing references to the constant still resolve.
    BODY_FORMATS = WebMock::Util::ContentType::BODY_FORMATS

    attr_reader :pattern

    def initialize(pattern)
      @pattern = pattern.is_a?(Hash) ? normalize_hash(pattern) : webmock_hash_matcher(pattern)
    end

    def matches?(body, content_type = "", serialized_body = nil)
      # Checked on the raw value, so body patterns used with mixed case
      # multipart content types keep working as in earlier versions.
      assert_non_multipart_body(content_type)

      if serialized_body
        case @pattern
        when String, Regexp, Hash, Array, WebMock::Matchers::HashArgumentMatcher, nil
          body = serialized_body
        end
      end

      if (@pattern).is_a?(Hash)
        return true if @pattern.empty?
        matching_body_hashes?(body_as_hash(body, content_type), @pattern, content_type)
      elsif (@pattern).is_a?(Array)
        matching_body_array?(body_as_hash(body, content_type), @pattern, content_type)
      elsif (@pattern).is_a?(WebMock::Matchers::HashArgumentMatcher)
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
      return if body.nil?

      case WebMock::Util::ContentType.body_format(content_type)
      when :json then
        WebMock::Util::Parsers::JSON.parse(body)
      when :xml then
        WebMock::Util::Parsers::XML.parse(body)
      else
        # A body that isn't valid UTF-8, such as an uploaded file, can't be
        # a URL encoded form, so it doesn't match a hash.
        return unless self.class.form_parseable?(body)
        WebMock::Util::QueryMapper.query_to_values(body, notation: Config.instance.query_values_notation)
      end
    rescue WebMock::Util::Parsers::ParseError
      nil
    end

    def assert_non_multipart_body(content_type)
      if content_type =~ %r{^multipart/form-data}
        raise ArgumentError.new("WebMock does not support matching body for multipart/form-data requests yet :(")
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
    def matching_body_hashes?(query_parameters, pattern, content_type)
      return false unless query_parameters.is_a?(Hash)
      return false unless query_parameters.keys.sort == pattern.keys.sort

      query_parameters.all? do |key, actual|
        expected = pattern[key]
        matching_values(actual, expected, content_type)
      end
    end

    def matching_body_array?(query_parameters, pattern, content_type)
      return false unless query_parameters.is_a?(Array)
      return false unless query_parameters.length == pattern.length

      query_parameters.each_with_index do |actual, index|
        expected = pattern[index]
        return false unless matching_values(actual, expected, content_type)
      end

      true
    end

    def matching_values(actual, expected, content_type)
      return matching_body_hashes?(actual, expected, content_type) if actual.is_a?(Hash) && expected.is_a?(Hash)
      return matching_body_array?(actual, expected, content_type) if actual.is_a?(Array) && expected.is_a?(Array)

      expected = WebMock::Util::ValuesStringifier.stringify_values(expected) if WebMock::Util::ContentType.url_encoded?(content_type)
      expected === actual
    end

    def empty_string?(string)
      string.nil? || string == ""
    end

    def normalize_hash(hash)
      Hash[WebMock::Util::HashKeysStringifier.stringify_keys!(hash, deep: true).sort]
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

    def pp_to_s
      WebMock::Util::Headers.pp_headers_string(@pattern)
    end

    private

    def empty_headers?(headers)
      headers.nil? || headers == {}
    end
  end

end
