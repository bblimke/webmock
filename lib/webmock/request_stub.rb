module WebMock
  class RequestStub
    attr_accessor :request_profile, :responses

    def initialize(method, uri)
      @request_profile = RequestProfile.new(method, uri)
      @responses = []
      self
    end

    def with(params)
      @request_profile.with(params)
      self
    end

    def to_return(*response_hashes)
      @responses.unshift [*response_hashes].flatten.reverse.map {|r| WebMock::Response.new(r)}
      @responses.flatten!
      self
    end

    def to_raise(*exceptions)
      @responses.unshift [*exceptions].flatten.reverse.map {|e| WebMock::Response.new(:exception => e)}
      @responses.flatten!
      self
    end

    def response
      if @responses.empty?
        WebMock::Response.new
      elsif @responses.length > 1
        @responses.pop
      else
        @responses[0]
      end
    end

    def then
      self
    end

  end
end
