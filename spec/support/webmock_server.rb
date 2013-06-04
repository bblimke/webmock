require 'webrick'
require 'logger'
require 'singleton'

class WebMockServer
  include Singleton

  attr_reader :port, :started

  def host_with_port
    "localhost:#{port}"
  end

  def concurrent
    unless RUBY_PLATFORM =~ /java/
      @pid = Process.fork do
        yield
      end
    else
      Thread.new { yield }
    end
  end

  def start
    @started = true
    server = WEBrick::GenericServer.new(:Port => 0, :Logger => Logger.new("/dev/null"))
    server.logger.level = 0
    @port = server.config[:Port]

    concurrent do
      ['TERM', 'INT'].each do |signal|
        trap(signal) do
          Thread.new do
            server.shutdown
          end
        end
      end
      server.start do |socket|
        socket.puts <<-EOT.gsub(/^\s+\|/, '')
          |HTTP/1.1 200 OK\r
          |Date: Fri, 31 Dec 1999 23:59:59 GMT\r
          |Content-Type: text/html\r
          |Content-Length: 11\r
          |Set-Cookie: bar\r
          |Set-Cookie: foo\r
          |\r
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
    if @pid
      Process.kill('INT', @pid)
    end
  end
end
