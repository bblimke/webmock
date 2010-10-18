module WebMock
  class Config 
    include Singleton
    
    attr_accessor :allow_net_connect
    attr_accessor :allow_localhost
    attr_accessor :allow
    
    attr_accessor :force_net_connect
    
  end
end
