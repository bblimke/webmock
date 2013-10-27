require 'spec_helper'

describe "errors" do
  describe WebMock::NetConnectNotAllowedError do
    describe "message" do
      it "should have message with request signature and snippet" do
        request_signature = double(:to_s => "aaa")
        request_stub = double
        WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
        WebMock::StubRequestSnippet.stub(:new).
          with(request_stub).and_return(double(:to_s => "bbb"))
        expected =  "Real HTTP connections are disabled. Unregistered request: aaa" +
               "\n\nYou can stub this request with the following snippet:\n\n" +
               "bbb\n\n============================================================"
        WebMock::NetConnectNotAllowedError.new(request_signature).message.should == expected
      end

      it "should have message with registered stubs if available" do
        request_signature = double(:to_s => "aaa")
        request_stub = double
        WebMock::StubRegistry.instance.stub(:request_stubs).and_return([request_stub])
        WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
        WebMock::StubRequestSnippet.stub(:new).
          with(request_stub).and_return(double(:to_s => "bbb"))
        expected =  "Real HTTP connections are disabled. Unregistered request: aaa" +
               "\n\nYou can stub this request with the following snippet:\n\n" +
               "bbb\n\nregistered request stubs:\n\nbbb\n\n============================================================"
        WebMock::NetConnectNotAllowedError.new(request_signature).message.should == expected
      end

      it "should not be caught by a rescue block without arguments" do
        request_signature = double(:to_s => "aaa")
        request_stub = double
        WebMock::RequestStub.stub(:from_request_signature).and_return(request_stub)
        WebMock::StubRequestSnippet.stub(:new).
          with(request_stub).and_return(double(:to_s => "bbb"))

        exception = WebMock::NetConnectNotAllowedError.new(request_signature)

        expect do
          begin
            raise exception
          rescue
            raise "exception should not be caught"
          end
        end.to raise_exception exception
      end
    end
  end
end
