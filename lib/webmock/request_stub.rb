module WebMock
  class RequestStub
    attr_accessor :request_profile, :response
    
    def initialize(method, url)
      @request_profile = RequestProfile.new(method, url)
      @response = WebMock::Response.new
      self
    end

    def with(params)
      @request_profile.body = params[:body]
      @request_profile.headers = Utility.normalize_headers(params[:headers])
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
