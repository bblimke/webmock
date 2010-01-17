module WebMock
  class Response
    attr_reader :options

    def initialize(options = {})
      self.options = options
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

    def options=(options)
      @options = options
      stringify_body!
    end

    def dup
      dup_response = super
      dup_response.options = options.dup
      dup_response
    end

    def ==(other)
      options == other.options
    end

    def stringify_body!
      if @options[:body].is_a?(IO)
        io = @options[:body]
        @options[:body] = io.read
        io.close
      end
    end

  end
end
