require 'spec_helper'

describe WebMock::StubRegistry do

  before(:each) do
    WebMock::StubRegistry.instance.reset!
    @request_pattern = WebMock::RequestPattern.new(:get, "www.example.com")
    @request_signature = WebMock::RequestSignature.new(:get, "www.example.com")
    @request_stub = WebMock::RequestStub.new(:get, "www.example.com")
  end

  describe "cleaning the stubs" do
    before(:each) do
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
    end

    it "should clean all request stubs" do
      WebMock::StubRegistry.instance.registered_request?(@request_signature).should == @request_stub
      WebMock::StubRegistry.instance.reset!
      WebMock::StubRegistry.instance.registered_request?(@request_signature).should == nil
    end

    it "should clean only one stub" do
      another_request_signature = WebMock::RequestSignature.new(:get, "www.another.example.com")
      another_request_stub = WebMock::RequestStub.new(:get, "www.another.example.com")
      WebMock::StubRegistry.instance.register_request_stub(another_request_stub)

      WebMock::StubRegistry.instance.registered_request?(@request_signature).should == @request_stub
      WebMock::StubRegistry.instance.unregister_request_stub(@request_stub)
      WebMock::StubRegistry.instance.registered_request?(@request_signature).should == nil

      WebMock::StubRegistry.instance.registered_request?(another_request_signature).should == another_request_stub
    end
  end

  describe "registering and reporting registered requests" do

    it "should return registered stub" do
      WebMock::StubRegistry.instance.register_request_stub(@request_stub).should == @request_stub
    end

    it "should report if request stub is not registered" do
      WebMock::StubRegistry.instance.registered_request?(@request_signature).should == nil
    end

    it "should register and report registered stib" do
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      WebMock::StubRegistry.instance.registered_request?(@request_signature).should == @request_stub
    end


  end

  describe "response for request" do

    it "should report registered evaluated response for request pattern" do
      @request_stub.to_return(:body => "abc")
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      WebMock::StubRegistry.instance.response_for_request(@request_signature).
        should == WebMock::Response.new(:body => "abc")
    end

    it "should report evaluated response" do
      @request_stub.to_return {|request| {:body => request.method.to_s} }
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      response1 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      response1.should == WebMock::Response.new(:body => "get")
    end

    it "should report clone of theresponse" do
      @request_stub.to_return {|request| {:body => request.method.to_s} }
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      response1 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      response2 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      response1.should_not be(response2)
    end

    it "should report nothing if no response for request is registered" do
      WebMock::StubRegistry.instance.response_for_request(@request_signature).should == nil
    end

    it "should always return last registered matching response" do
      @request_stub1 = WebMock::RequestStub.new(:get, "www.example.com")
      @request_stub1.to_return(:body => "abc")
      @request_stub2 = WebMock::RequestStub.new(:get, "www.example.com")
      @request_stub2.to_return(:body => "def")
      @request_stub3 = WebMock::RequestStub.new(:get, "www.example.org")
      @request_stub3.to_return(:body => "ghj")
      WebMock::StubRegistry.instance.register_request_stub(@request_stub1)
      WebMock::StubRegistry.instance.register_request_stub(@request_stub2)
      WebMock::StubRegistry.instance.register_request_stub(@request_stub3)
      WebMock::StubRegistry.instance.response_for_request(@request_signature).
        should == WebMock::Response.new(:body => "def")
    end

  end

end
