module WebMock
  class Response

    def initialize(options = {})
      @options = options
    end

    def headers
      Util::Headers.normalize_headers(@options[:headers])
    end

    def body
      return '' unless @options.has_key?(:body)

      if !@options[:body].include?("\0") && File.exists?(@options[:body]) && !File.directory?(@options[:body])
        File.read(@options[:body])
      else
        @options[:body]
      end
    end
    
    def status
      @options.has_key?(:status) ? @options[:status] : 200
    end

    def raise_error_if_any
      raise @options[:exception].new('Exception from WebMock') if @options.has_key?(:exception)
    end

  end
end
