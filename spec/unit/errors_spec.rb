require 'spec_helper'

describe "errors" do
  describe WebMock::NetConnectNotAllowedError do
    describe "message" do
      it "should have message with request signature and snippet" do
        WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
        WebMock::StubRequestSnippet.stub(:new).
           with(request_stub).and_return(stub_result)

        expected =  \
          "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
          "\n\nYou can stub this request with the following snippet:" \
          "\n\n#{stub_result}" \
          "\n\n============================================================"
        WebMock::NetConnectNotAllowedError.new(request_signature).message.should == expected
      end

      it "should have message with registered stubs if available" do
        WebMock::StubRegistry.instance.stub(:request_stubs).and_return([request_stub])
        WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
        WebMock::StubRequestSnippet.stub(:new).
           with(request_stub).and_return(stub_result)

        expected =  \
          "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
          "\n\nYou can stub this request with the following snippet:" \
          "\n\n#{stub_result}" \
          "\n\nregistered request stubs:" \
          "\n\n#{stub_result}" \
          "\n\n============================================================"
        WebMock::NetConnectNotAllowedError.new(request_signature).message.should == expected
      end

      it "should not be caught by a rescue block without arguments" do
        WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
        WebMock::StubRequestSnippet.stub(:new).
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

      context "WebMock.show_stubbing_instructions? is false" do
        before do
          WebMock.hide_stubbing_instructions!
        end

        it "should have message with request signature and snippet" do
          WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
          WebMock::StubRequestSnippet.stub(:new).
            with(request_stub).and_return(stub_result)

          expected =  \
            "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
            "\n\n============================================================"
          WebMock::NetConnectNotAllowedError.new(request_signature).message.should == expected
        end

        it "should have message with registered stubs if available" do
          WebMock::StubRegistry.instance.stub(:request_stubs).and_return([request_stub])
          WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
          WebMock::StubRequestSnippet.stub(:new).
            with(request_stub).and_return(stub_result)

          expected =  \
            "Real HTTP connections are disabled. Unregistered request: #{request_signature}" \
            "\n\nregistered request stubs:" \
            "\n\n#{stub_result}" \
            "\n\n============================================================"
          WebMock::NetConnectNotAllowedError.new(request_signature).message.should == expected
        end
      end
    end

    let(:request_signature) { double(:to_s => rand(10**20).to_s) }
    let(:stub_result)       { double(:to_s => rand(10**20).to_s) }
    let(:request_stub)      { double }

  end
end
