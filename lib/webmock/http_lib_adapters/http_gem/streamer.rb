module HTTP
  class Response
    class Streamer
      def initialize(str)
        @io = StringIO.new str
      end

      def readpartial(size = HTTP::Client::BUFFER_SIZE)
        @io.read size
      end
    end
  end
end
