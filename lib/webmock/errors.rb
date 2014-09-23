module WebMock

  class NetConnectNotAllowedError < Exception
    def initialize(request_signature)
      text = [
        "Real HTTP connections are disabled. Unregistered request: #{request_signature}",
        stubbing_instructions(request_signature),
        request_stubs,
        "="*60
      ].compact.join("\n\n")
      super(text)
    end

    private

    def request_stubs
      return if WebMock::StubRegistry.instance.request_stubs.empty?
      text = "registered request stubs:\n"
      WebMock::StubRegistry.instance.request_stubs.each do |stub|
        text << "\n#{WebMock::StubRequestSnippet.new(stub).to_s(false)}"
      end
      text
    end

    def stubbing_instructions(request_signature)
      return unless WebMock.show_stubbing_instructions?
      text = ""
      request_stub = RequestStub.from_request_signature(request_signature)
      text << "You can stub this request with the following snippet:\n\n"
      text << WebMock::StubRequestSnippet.new(request_stub).to_s
      text
    end
  end

end
