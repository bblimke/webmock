require "pp"
module WebMock
  class RequestSignatureSnippet

    attr_reader :request_signature, :request_stub

    def initialize(request_signature)
      @request_signature = request_signature
      @request_stub = create_request_stub
    end

    def stubbing_instructions
      return unless WebMock.show_stubbing_instructions?
      text = ""
      text << "You can stub this request with the following snippet:\n\n"
      text << WebMock::StubRequestSnippet.new(request_stub).to_s
      text
    end


    def signature_stub_body_diff(stub)
      diff = RequestBodyDiff.new(request_signature, stub).body_diff
      diff.empty? ? "" : "Body diff:\n #{pretty_print_to_string(diff)}"
    end

    def request_params
      @request_params ||= case request_signature.headers["Content-Type"]
        when "application/json"
          JSON.parse(request_signature.body)
        else
          ""
      end
    end

    def request_stubs
      return if WebMock::StubRegistry.instance.request_stubs.empty?
      text = "registered request stubs:\n"
      WebMock::StubRegistry.instance.request_stubs.each do |stub|
        text << "\n#{WebMock::StubRequestSnippet.new(stub).to_s(false)}"
        if WebMock.show_body_diff?
          body_diff_str = signature_stub_body_diff(stub)
          text << "\n\n#{body_diff_str}" if !body_diff_str.empty?
        end
      end
      text
    end


    private

    def create_request_stub
      RequestStub.from_request_signature(request_signature)
    end

    def pretty_print_to_string(string_to_print)
      StringIO.open("") do |stream|
        PP.pp(string_to_print, stream)
        stream.rewind
        stream.read
      end
    end

  end
end
