require 'socket'

module LocalHTTPServer
  # Yields the port of a server on 127.0.0.1 while real requests are
  # allowed, answers each of the given number of requests with an empty
  # 200, and returns the heads the server received, so a spec can check
  # what a client really sends.
  def capture_request_heads(count = 1)
    server = TCPServer.new("127.0.0.1", 0)
    thread = Thread.new do
      heads = Array.new(count) do
        client = server.accept
        begin
          head = +""
          while (line = client.gets) && line != "\r\n"
            head << line
          end
          length = head[/^content-length:\s*(\d+)/i, 1].to_i
          client.read(length) if length > 0
          client.write("HTTP/1.1 200 OK\r\nContent-Length: 0\r\nConnection: close\r\n\r\n")
          head
        ensure
          client.close
        end
      end
      # A request beyond the expected count then fails instead of waiting.
      server.close
      heads
    end
    thread.report_on_exception = false

    WebMock.allow_net_connect! { yield server.addr[1] }
    raise "Expected #{count} requests to reach the server" unless thread.join(10)
    thread.value
  ensure
    thread&.kill
    server&.close
  end
end
