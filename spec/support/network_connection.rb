require 'timeout'
require 'socket'

module NetworkConnection
  def self.connect_to(host, port, timeout=10)
    Timeout.timeout(timeout) do
      TCPSocket.new(host, port)
    end
  end

  def self.is_network_available?
    begin
      self.connect_to("8.8.8.8", 53, 5)
      true
    rescue
      false
    end
  end
end
