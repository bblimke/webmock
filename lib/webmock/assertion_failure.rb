module WebMock
  class AssertionFailure
    class << self
      attr_writer :error_class
      @error_class = RuntimeError
    
      def failure(message)
        raise @error_class.new(message)
      end
    
    end
  end
end