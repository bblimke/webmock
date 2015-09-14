require "spec_helper"

RSpec.describe WebMock::RequestSignatureSnippet do
  it("is real"){expect{subject}.not_to(raise_error)}

  subject { WebMock::RequestSignatureSnippet.new(request_signature) }

  let(:uri) { "http://example.com" }
  let(:method) { "GET" }

  let(:request_signature) { WebMock::RequestSignature.new(method, uri) }
  let(:request_signature_body) { {"key" => "different value"}.to_json }

  let(:request_pattern) {
    WebMock::RequestPattern.new(
      method, uri, {:body => request_signature_body}
    )
  }

  before :each do
    request_signature.headers = {"Content-Type" => "application/json"}
    request_signature.body = request_signature_body
  end

  describe "#stubbing_instructions" do
    context "with stubbing instructions turned off" do
      before :each do
        WebMock.hide_stubbing_instructions!
      end

      it "returns nil" do
        expect(subject.stubbing_instructions).to be nil
      end

      after :each do
        WebMock.show_stubbing_instructions!
      end
    end

    context "with stubbing instructions turned on" do
      it "returns a stub snippet" do
        expect(subject.stubbing_instructions).to include(
          "You can stub this request with the following snippet:"
        )
      end
    end
  end

  describe "#request_stubs" do
    before :each do
      WebMock.stub_request(:get, "https://www.example.com").with(:body => {"a" => "b"})
    end

    context "when showing the body diff is turned off" do
      before :each do
        WebMock.hide_body_diff!
      end

      it "returns does not show the body diff" do
        result = subject.request_stubs
        result.sub!("registered request stubs:\n\n", "")
        expect(result).to eq(
          "stub_request(:get, \"https://www.example.com/\").\n  with(:body => {\"a\"=>\"b\"})"
        )
      end

      after :each do
        WebMock.show_body_diff!
      end
    end

    context "when showing the body diff is turned on" do
      it "shows the body diff" do
        result = subject.request_stubs
        result.sub!("registered request stubs:\n\n", "")
        expect(result).to eq(
          "stub_request(:get, \"https://www.example.com/\").\n  with(:body => {\"a\"=>\"b\"})\n\nBody diff:\n [[\"-\", \"key\", \"different value\"], [\"+\", \"a\", \"b\"]]\n"
        )
      end
    end

    context "with no request stubs" do
      it "returns nil" do
        WebMock.reset!
        expect(subject.request_stubs).to be nil
      end
    end
  end
end
