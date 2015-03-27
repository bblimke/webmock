module HTTP
  class Response
    class Streamer
      def initialize(str)
        @io = StringIO.new str
      end

      def readpartial(size = nil)
        unless size
          if defined?(HTTP::Client::BUFFER_SIZE)
            size = HTTP::Client::BUFFER_SIZE
          elsif defined?(HTTP::Connection::BUFFER_SIZE)
            size = HTTP::Connection::BUFFER_SIZE
          end
        end

        @io.read size
      end

      def sequence_id
        -1
      end
    end
  end
end
