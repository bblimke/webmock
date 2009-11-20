module WebMock
  class Config 
    include Singleton
    
    attr_accessor :allow_net_connect
  end
end