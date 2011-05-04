require 'webrick'
require 'logger'
class WebMockServer
  include Singleton

  attr_reader :port

  def host_with_port
    "localhost:#{port}"
  end

  def start
    server = WEBrick::GenericServer.new(:Port => 0, :Logger => Logger.new("/dev/null"))
    server.logger.level = 0
    @port = server.config[:Port]

    @pid = fork do
      server.logger.level = 0
      trap("INT"){ server.shutdown }

      server.start do |socket|
        socket.puts <<-EOT.gsub(/^\s+\|/, '')
          |HTTP/1.0 200 OK
          |Date: Fri, 31 Dec 1999 23:59:59 GMT
          |Content-Type: text/html
          |Content-Length: 11
          |
          |hello world
        EOT
      end
    end

    loop do
      begin
        s = TCPSocket.new("localhost", port)
        sleep 0.1
        break
      rescue Errno::ECONNREFUSED
        sleep 0.1
      end
    end
  end

  def stop
    Process.kill("INT", @pid) if @pid
  end
end
