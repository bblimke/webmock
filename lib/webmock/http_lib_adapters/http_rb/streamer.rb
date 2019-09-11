module HTTP
  class Response
    class Streamer
      def initialize(str)
        @io = StringIO.new str
      end

      def readpartial(size = nil, outbuf = nil)
        unless size
          if defined?(HTTP::Client::BUFFER_SIZE)
            size = HTTP::Client::BUFFER_SIZE
          elsif defined?(HTTP::Connection::BUFFER_SIZE)
            size = HTTP::Connection::BUFFER_SIZE
          end
        end

        @io.read size, outbuf
      end

      def close
        @io.close
      end

      def sequence_id
        -1
      end
    end
  end
end
