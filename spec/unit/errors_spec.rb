require 'spec_helper'

describe "errors" do
  describe WebMock::NetConnectNotAllowedError do
    describe "message" do
      it "should have message with request signature and snippet" do
        allow(WebMock::RequestStub).to receive(:from_request_signature).and_return(request_stub)
        allow(WebMock::StubRequestSnippet).to receive(:new).
           with(request_stub).and_return(stub_result)

        expected =  \
          "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
          "\n\nYou can stub this request with the following snippet:" \
          "\n\n#{stub_result}" \
          "\n\n============================================================"
        expect(WebMock::NetConnectNotAllowedError.new(request_signature).message).to eq(expected)
      end

      it "should have message with registered stubs if available" do
        allow(WebMock::StubRegistry.instance).to receive(:request_stubs).and_return([request_stub])
        allow(WebMock::RequestStub).to receive(:from_request_signature).and_return(request_stub)
        allow(WebMock::StubRequestSnippet).to receive(:new).
           with(request_stub).and_return(stub_result)
        allow_any_instance_of(WebMock::RequestBodyDiff).to receive(:body_diff).and_return({})

        expected =  \
          "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
          "\n\nYou can stub this request with the following snippet:" \
          "\n\n#{stub_result}" \
          "\n\nregistered request stubs:" \
          "\n\n#{stub_result}" \
          "\n\n============================================================"
        expect(WebMock::NetConnectNotAllowedError.new(request_signature).message).to eq(expected)
      end

      it "should not be caught by a rescue block without arguments" do
        allow(WebMock::RequestStub).to receive(:from_request_signature).and_return(request_stub)
        allow(WebMock::StubRequestSnippet).to receive(:new).
          with(request_stub).and_return(stub_result)

        exception = WebMock::NetConnectNotAllowedError.new(request_signature)

        expect do
          begin
            raise exception
          rescue
            raise "exception should not be caught"
          end
        end.to raise_exception exception
      end

      it "should print body diff if available" do
        allow(WebMock::StubRegistry.instance).to receive(:request_stubs).and_return([request_stub])
        allow(WebMock::RequestStub).to receive(:from_request_signature).and_return(request_stub)
        allow(WebMock::StubRequestSnippet).to receive(:new).
           with(request_stub).and_return(stub_result)
        allow_any_instance_of(WebMock::RequestBodyDiff).to receive(:body_diff).and_return(body_diff)
        expected =  \
          "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
          "\n\nYou can stub this request with the following snippet:" \
          "\n\n#{stub_result}" \
          "\n\nregistered request stubs:" \
          "\n\n#{stub_result}" \
          "\n\nBody diff:\n [[\"+\", \"test\", \"test2\"], [\"-\", \"test3\"], [\"~\", \"test5\", \"test6\"]]" \
          "\n\n\n============================================================"
        expect(WebMock::NetConnectNotAllowedError.new(request_signature).message).to eq(expected)
      end

      context "WebMock.show_body_diff? is false" do
        before do
          WebMock.hide_body_diff!
        end
        it "should not show body diff" do
          allow(WebMock::StubRegistry.instance).to receive(:request_stubs).and_return([request_stub])
          allow(WebMock::RequestStub).to receive(:from_request_signature).and_return(request_stub)
          allow(WebMock::StubRequestSnippet).to receive(:new).
             with(request_stub).and_return(stub_result)
          expect_any_instance_of(WebMock::RequestBodyDiff).to_not receive(:body_diff)
          expected =  \
            "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
            "\n\nYou can stub this request with the following snippet:" \
            "\n\n#{stub_result}" \
            "\n\nregistered request stubs:" \
            "\n\n#{stub_result}" \
            "\n\n============================================================"
          expect(WebMock::NetConnectNotAllowedError.new(request_signature).message).to eq(expected)
        end
      end

      context "WebMock.show_stubbing_instructions? is false" do
        before do
          WebMock.hide_stubbing_instructions!
        end

        it "should have message with request signature and snippet" do
          allow(WebMock::RequestStub).to receive(:from_request_signature).and_return(request_stub)
          allow(WebMock::StubRequestSnippet).to receive(:new).
            with(request_stub).and_return(stub_result)

          expected =  \
            "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
            "\n\n============================================================"
          expect(WebMock::NetConnectNotAllowedError.new(request_signature).message).to eq(expected)
        end

        it "should have message with registered stubs if available" do
          allow(WebMock::StubRegistry.instance).to receive(:request_stubs).and_return([request_stub])
          allow(WebMock::RequestStub).to receive(:from_request_signature).and_return(request_stub)
          allow(WebMock::StubRequestSnippet).to receive(:new).
            with(request_stub).and_return(stub_result)
          allow(request_stub).to receive(:request_pattern).and_return(body_pattern)

          expected =  \
            "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
            "\n\nregistered request stubs:" \
            "\n\n#{stub_result}" \
            "\n\n============================================================"
          expect(WebMock::NetConnectNotAllowedError.new(request_signature).message).to eq(expected)
        end
      end
    end

    let(:request_signature) { double(:request_signature, to_s: rand(10**20).to_s) }
    let(:stub_result)       { double(:stub_result, to_s: rand(10**20).to_s) }
    let(:request_stub)      { double(:request_stub) }
    let(:body_pattern)      { double(:body_pattern, body_pattern: nil)}
    let(:body_diff)         { [["+", "test", "test2"], ["-", "test3"], ["~", "test5", "test6"]] }
  end
end
