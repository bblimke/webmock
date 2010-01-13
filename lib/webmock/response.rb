module WebMock
  class Response
    attr_accessor :options

    def initialize(options = {})
      @options = options
      @options[:headers] = Util::Headers.normalize_headers(@options[:headers]) unless @options[:headers].is_a?(Proc)
    end

    def headers
      @options[:headers]
    end

    def body
      return '' unless @options.has_key?(:body)
      stringify_body!
      @options[:body]
    end

    def status
      @options.has_key?(:status) ? @options[:status] : 200
    end

    def raise_error_if_any
      raise @options[:exception].new('Exception from WebMock') if @options.has_key?(:exception)
    end

    def dup
      stringify_body!
      dup_response = super
      dup_response.options = options.dup
      dup_response
    end

    def ==(other)
      options == other.options
    end

    def stringify_body!
      if @options[:body].is_a?(IO)
        @options[:body] = @options[:body].read
      end
    end

  end
end
