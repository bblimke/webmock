module WebMock
  class RequestStub
    attr_accessor :request_profile, :response
    
    def initialize(method, uri)
      @request_profile = RequestProfile.new(method, uri)
      @response = WebMock::Response.new
      self
    end

    def with(params = {}, &block)
      @request_profile.with(params, &block)
      self
    end

    def to_return(response_hash)
      @response = WebMock::Response.new(response_hash)
    end
    
    def to_raise(exception)
      @response = WebMock::Response.new({:exception => exception})
    end
    
  end
end
