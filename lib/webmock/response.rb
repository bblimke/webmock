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
      case @options[:body]
      when IO
        @options[:body].read
      when String
        @options[:body]
      end
    end

    def status
      @options.has_key?(:status) ? @options[:status] : 200
    end

    def raise_error_if_any
      raise @options[:exception].new('Exception from WebMock') if @options.has_key?(:exception)
    end

    def dup
      dup_response = super
      dup_response.options = options.dup
      dup_response
    end

    def ==(other)
      options == other.options
    end

  end
end
