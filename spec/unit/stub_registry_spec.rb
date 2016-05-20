require 'spec_helper'

describe WebMock::StubRegistry do

  before(:each) do
    WebMock::StubRegistry.instance.reset!
    @request_pattern = WebMock::RequestPattern.new(:get, "www.example.com")
    @request_signature = WebMock::RequestSignature.new(:get, "www.example.com")
    @request_stub = WebMock::RequestStub.new(:get, "www.example.com")
  end

  describe "remove_request_stub" do
    it "should remove stub from registry" do
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      expect(WebMock::StubRegistry.instance.registered_request?(@request_signature)).to eq(@request_stub)
      WebMock::StubRegistry.instance.remove_request_stub(@request_stub)
      expect(WebMock::StubRegistry.instance.registered_request?(@request_signature)).to eq(nil)
    end
  end

  describe "reset!" do
    before(:each) do
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
    end

    it "should clean request stubs" do
      expect(WebMock::StubRegistry.instance.registered_request?(@request_signature)).to eq(@request_stub)
      WebMock::StubRegistry.instance.reset!
      expect(WebMock::StubRegistry.instance.registered_request?(@request_signature)).to eq(nil)
    end
  end

  describe "registering and reporting registered requests" do

    it "should return registered stub" do
      expect(WebMock::StubRegistry.instance.register_request_stub(@request_stub)).to eq(@request_stub)
    end

    it "should report if request stub is not registered" do
      expect(WebMock::StubRegistry.instance.registered_request?(@request_signature)).to eq(nil)
    end

    it "should register and report registered stub" do
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      expect(WebMock::StubRegistry.instance.registered_request?(@request_signature)).to eq(@request_stub)
    end


  end

  describe "response for request" do

    it "should report registered evaluated response for request pattern" do
      @request_stub.to_return(body: "abc")
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      expect(WebMock::StubRegistry.instance.response_for_request(@request_signature)).
        to eq(WebMock::Response.new(body: "abc"))
    end

    it "should report evaluated response" do
      @request_stub.to_return {|request| {body: request.method.to_s} }
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      response1 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      expect(response1).to eq(WebMock::Response.new(body: "get"))
    end

    it "should report clone of the response" do
      @request_stub.to_return(body: lambda{|r| r.method.to_s})
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      response1 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      response2 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      expect(response1).not_to be(response2)
    end

    it "should report clone of the dynamic response" do
      @request_stub.to_return {|request| {body: request.method.to_s} }
      WebMock::StubRegistry.instance.register_request_stub(@request_stub)
      response1 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      response2 = WebMock::StubRegistry.instance.response_for_request(@request_signature)
      expect(response1).not_to be(response2)
    end

    it "should report nothing if no response for request is registered" do
      expect(WebMock::StubRegistry.instance.response_for_request(@request_signature)).to eq(nil)
    end

    it "should always return last registered matching response" do
      @request_stub1 = WebMock::RequestStub.new(:get, "www.example.com")
      @request_stub1.to_return(body: "abc")
      @request_stub2 = WebMock::RequestStub.new(:get, "www.example.com")
      @request_stub2.to_return(body: "def")
      @request_stub3 = WebMock::RequestStub.new(:get, "www.example.org")
      @request_stub3.to_return(body: "ghj")
      WebMock::StubRegistry.instance.register_request_stub(@request_stub1)
      WebMock::StubRegistry.instance.register_request_stub(@request_stub2)
      WebMock::StubRegistry.instance.register_request_stub(@request_stub3)
      expect(WebMock::StubRegistry.instance.response_for_request(@request_signature)).
        to eq(WebMock::Response.new(body: "def"))
    end

  end

end
