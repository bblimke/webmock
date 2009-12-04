module WebMock

  class RequestRegistry
    include Singleton

    attr_accessor :request_stubs, :requested_signatures

    def initialize
      reset_webmock
    end

    def reset_webmock
      self.request_stubs = []
      self.requested_signatures = Util::HashCounter.new
    end

    def register_request_stub(stub)
      request_stubs.insert(0, stub)
      stub
    end

    def registered_request?(request_signature)
      request_stub_for(request_signature)
    end

    def response_for_request(request_signature)
      stub = request_stub_for(request_signature)
      stub ? evaluate_response_for_request(stub.response, request_signature) : nil
    end

    def times_executed(request_profile)
      self.requested_signatures.hash.select { |request_signature, times_executed|
        request_signature.match(request_profile)
      }.inject(0) {|sum, (_, times_executed)| sum + times_executed }
    end

    private

    def request_stub_for(request_signature)
      request_stubs.detect { |registered_request_stub|
        request_signature.match(registered_request_stub.request_profile)
      }
    end

    def evaluate_response_for_request(response, request_signature)
      evaluated_response = response.dup
      evaluated_response.options[:body] = response.body.call(request_signature).to_s if response.body.is_a?(Proc)
      evaluated_response.options[:headers] = response.headers.call(request_signature) if response.headers.is_a?(Proc)
      evaluated_response
    end

  end
end
