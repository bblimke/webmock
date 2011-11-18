module WebMock

  class StubRegistry
    include Singleton

    attr_accessor :request_stubs
    attr_accessor :global_stub

    def initialize
      reset!
    end

    def reset!
      self.request_stubs = global_stub ? [global_stub] : []
    end

    def global_stub_block=(block)
      self.global_stub = ::WebMock::RequestStub.new(:any, /.*/)

      # This hash contains the responses returned by the block,
      # keyed by the exact request (using the object_id).
      # That way, there's no race condition in case #to_return
      # doesn't run immediately after stub.with.
      responses = {}

      self.global_stub.with { |request|
        responses[request.object_id] = block.call(request)
      }.to_return(lambda { |request| responses.delete(request.object_id) })

      register_request_stub(self.global_stub)
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

    private

    def request_stub_for(request_signature)
      request_stubs.detect { |registered_request_stub|
        registered_request_stub.request_pattern.matches?(request_signature)
      }
    end

    def evaluate_response_for_request(response, request_signature)
      response.evaluate(request_signature)
    end

  end
end
