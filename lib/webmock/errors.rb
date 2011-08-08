module WebMock

  class NetConnectNotAllowedError < StandardError
    def initialize(request_signature)
      text = "Real HTTP connections are disabled. Unregistered request: #{request_signature}"
      text << stubbing_instructions(request_signature)
      super(text)
    end

    private

    def stubbing_instructions(request_signature)
      request_stub = RequestStub.from_request_signature(request_signature)
      text = "\n\n"
      text << "You can stub this request with the following snippet:\n\n"
      text << WebMock::StubRequestSnippet.new(request_stub).to_s
      text << "\n\n" + "="*60
      text
    end
  end

end
