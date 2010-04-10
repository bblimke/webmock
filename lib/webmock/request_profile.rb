module WebMock

  class RequestProfile < Request

    attr_reader :with_block

    def with(options = {}, &block)
      assign_options(options)
      @with_block = block
      self
    end

    def body=(body)
      @body = Body.new(body)
    end

    def body
      @body.value
    end

    class Body

      attr_reader :data

      def initialize(data)
        @data = data
      end

      def ==(other)
        other = Body.new(other) unless other.is_a?(Body)
        other.is_empty? && self.is_empty? || other.data == self.data || self.data === other.data
      end

      def is_empty?
        @data.nil? || @data == ""
      end

      def to_s
        @data
      end
    end

    def headers=(headers)
      @headers = Headers.new(headers)
    end
    
    def headers
      @headers.headers
    end
    
    class Headers
      attr_reader :headers

      def initialize(headers)
        @headers = headers
        normalize!
      end

      def ==(other)
        other = Headers.new(other) unless other.is_a?(Headers)
        other.empty? && self.empty? || other.headers == self.headers
      end

      def empty?
        @headers.nil? || @headers == {}
      end

      def to_s
        @headers.inspect.gsub("\"","'")
      end

      def is_subset_of?(headers)
        return false if @headers.nil? || @headers.empty?
        headers = WebMock::Util::Headers.normalize_headers(headers)
        return false if headers.nil?
        @headers.to_a.to_set.subset?(headers.to_a.to_set)
      end

      private

      def normalize!
        @headers = WebMock::Util::Headers.normalize_headers(@headers)
      end
    end

    def to_s
      string = super
      string << " with given block" if @with_block
      string
    end

  end


end
