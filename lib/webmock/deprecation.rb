module WebMock
  class Deprecation
    class << self
      def warning(message)
        $stderr.puts "WebMock deprecation warning: #{message}"
      end
    end
  end
end
