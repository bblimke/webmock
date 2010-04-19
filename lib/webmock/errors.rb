module WebMock
  
  class NetConnectNotAllowedError < StandardError
    def initialize(request_signature)
      super("Real HTTP connections are disabled. Unregistered request: #{request_signature}")
    end
  end

end