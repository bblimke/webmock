module WebMock
  class RequestStub
    attr_accessor :request_profile, :responses
    
    def initialize(method, uri)
      @request_profile = RequestProfile.new(method, uri)
      @responses = [WebMock::Response.new]
      self
    end

    def with(params)
      @request_profile.with(params)
      self
    end

    def to_return(response_hashes)
      @responses = [response_hashes].flatten.reverse.map {|r| WebMock::Response.new(r)}
    end
    
    def to_raise(exceptions)
      @responses = [exceptions].flatten.reverse.map {|e| WebMock::Response.new(:exception => e)}
    end
    
    def response
      @responses.length > 1 ? @responses.pop : @responses[0]
    end
    
  end
end
