#compatibility with Ruby 1.9.2 preview1 to allow reading raw responses
class StringIO
  alias_method :read_nonblock, :sysread
end

module WebMock
  
  class Response
    attr_reader :options

    def initialize(options = {})
      if options.is_a?(IO) || options.is_a?(String) 
          self.options = read_raw_response(options)
        else
          self.options = options
      end
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
    
    private 

    def stringify_body!
      if @options[:body].is_a?(IO)
        io = @options[:body]
        @options[:body] = io.read
        io.close
      end
    end
    
    def read_raw_response(raw_response)
      if raw_response.is_a?(IO)
        string = raw_response.read 
        raw_response.close
        raw_response = string
      end        
      socket = Net::BufferedIO.new(raw_response)    
      response = Net::HTTPResponse.read_new(socket)
      transfer_encoding = response.delete('transfer-encoding') #chunks were already read by curl
      response.reading_body(socket, true) {}
      
      options = {}
      options[:headers] = {}
      response.each_header {|name, value| options[:headers][name] = value}
      options[:headers]['transfer-encoding'] = transfer_encoding if transfer_encoding
      options[:body] = response.read_body
      options      
    end

  end
end
