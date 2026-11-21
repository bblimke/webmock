# frozen_string_literal: true

module WebMock

  class RequestSignature

    attr_accessor :uri, :body
    attr_reader :method, :headers, :serialized_body

    def initialize(method, uri, options = {})
      self.method = method
      self.uri = uri.is_a?(Addressable::URI) ? uri : WebMock::Util::URI.normalize_uri(uri)
      @serialized_body = options[:serialized_body]
      assign_options(options)
    end

    def to_s
      string = "#{self.method.to_s.upcase}".dup
      string << " #{WebMock::Util::URI.strip_default_port_from_uri_string(self.uri.to_s)}"
      string << " with body '#{body.to_s}'" if body && body.to_s != ''
      if headers && !headers.empty?
        string << " with headers #{WebMock::Util::Headers.sorted_headers_string(headers)}"
      end
      string
    end

    # Build a signature for history while preserving the original client
    # objects for stub matchers and callbacks. Keep nested form structure.
    def with_body_values(&block)
      self.class.new(method, uri, body: map_body_values(body, &block), headers: headers)
    end

    # Keep the native upload available to custom matchers and callbacks while
    # allowing string and structured body patterns to match its contents.
    def with_upload_body(upload)
      self.class.new(method, uri, body: upload, headers: headers, serialized_body: body)
    end

    # A copy that shares no mutable state with the original.
    def initialize_copy(original)
      super
      @uri = @uri.dup
      @body = map_body_values(@body, &:dup)
      @serialized_body = @serialized_body&.dup
      @headers = @headers&.transform_values { |value| value.is_a?(Array) ? value.map(&:dup) : value.dup }
    end

    def method=(method)
      @method = method.to_sym.downcase
    end

    def headers=(headers)
      @headers = WebMock::Util::Headers.normalize_headers(headers)
    end

    def hash
      [method, uri, body, body_encoding, headers].hash
    end

    def eql?(other)
      other.is_a?(RequestSignature) &&
        method == other.method && uri.eql?(other.uri) &&
        body.eql?(other.body) && body_encoding == other.body_encoding && headers.eql?(other.headers)
    end
    alias == eql?

    # A request can carry Content-Type more than once, in which case the
    # normalized header value is an Array. Use its first value.
    def content_type
      Array(headers&.fetch('Content-Type', nil)).first
    end

    def url_encoded?
      WebMock::Util::ContentType.url_encoded?(content_type)
    end

    def json_headers?
      WebMock::Util::ContentType.body_format(content_type) == :json
    end

    protected

    def body_encoding
      body.encoding if body.is_a?(String)
    end

    private

    def map_body_values(body, &block)
      case body
      when Array
        body.map { |item| map_body_values(item, &block) }
      when Hash
        body.each_with_object({}) do |(key, value), copy|
          copy[map_body_values(key, &block)] = map_body_values(value, &block)
        end
      else
        yield body
      end
    end

    def assign_options(options)
      self.body = options[:body] if options.has_key?(:body)
      self.headers = options[:headers] if options.has_key?(:headers)
    end

  end

end
