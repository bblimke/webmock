module WebMock

  class RequestRegistry
    include Singleton

    attr_accessor :request_stubs, :requested

    def initialize
      reset_webmock
    end

    def reset_webmock
      self.request_stubs = []
      self.requested = HashCounter.new
    end

    def register_request_stub(stub)
      request_stubs.insert(0, stub)
      stub
    end

    def registered_request?(request_profile)
      stub_for(request_profile)
    end

    def response_for_request(request_profile)
      stub = stub_for(request_profile)
      self.requested.put(request_profile)
      stub ? stub.response : nil
    end
    
    def times_executed(request_profile)
      self.requested.hash.select { |executed_request_profile, times_executed|
        executed_request_profile.match(request_profile)
      }.inject(0) {|sum, (_, times_executed)| sum + times_executed }
    end

    private

    def stub_for(request_profile)
      request_stubs.detect { |registered_request_stub|
        request_profile.match(registered_request_stub.request_profile)
      }
    end

  end
end
