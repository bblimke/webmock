module WebMock
  class Config 
    include Singleton
    
    attr_accessor :allow_net_connect
    attr_accessor :allow_localhost
  end
end
