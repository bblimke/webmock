require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestRegistry do

  before(:each) do
    RequestRegistry.instance.reset_webmock
    @request_pattern = RequestPattern.new(:get, "www.example.com")
    @request_signature = RequestSignature.new(:get, "www.example.com")
    @request_stub = RequestStub.new(:get, "www.example.com")
  end

  describe "reset_webmock" do
    before(:each) do
      RequestRegistry.instance.register_request_stub(@request_stub)
      RequestRegistry.instance.requested_signatures.put(@request_signature)
    end

    it "should clean request stubs" do
      RequestRegistry.instance.registered_request?(@request_signature).should == @request_stub
      RequestRegistry.instance.reset_webmock
      RequestRegistry.instance.registered_request?(@request_signature).should == nil
    end

    it "should clean list of executed requests" do
      RequestRegistry.instance.times_executed(@request_pattern).should == 1
      RequestRegistry.instance.reset_webmock
      RequestRegistry.instance.times_executed(@request_pattern).should == 0
    end

  end

  describe "registering and reporting registered requests" do

    it "should return registered stub" do
      RequestRegistry.instance.register_request_stub(@request_stub).should == @request_stub
    end

    it "should report if request stub is not registered" do
      RequestRegistry.instance.registered_request?(@request_signature).should == nil
    end

    it "should register and report registered stib" do
      RequestRegistry.instance.register_request_stub(@request_stub)
      RequestRegistry.instance.registered_request?(@request_signature).should == @request_stub
    end


  end

  describe "response for request" do

    it "should report registered evaluated response for request pattern" do
      @request_stub.to_return(:body => "abc")
      RequestRegistry.instance.register_request_stub(@request_stub)
      RequestRegistry.instance.response_for_request(@request_signature).should == Response.new(:body => "abc")
    end

    it "should report evaluated response" do
      @request_stub.to_return {|request| {:body => request.method.to_s} }
      RequestRegistry.instance.register_request_stub(@request_stub)
      response1 = RequestRegistry.instance.response_for_request(@request_signature)
      response1.should == Response.new(:body => "get")
    end

    it "should report clone of theresponse" do
      @request_stub.to_return {|request| {:body => request.method.to_s} }
      RequestRegistry.instance.register_request_stub(@request_stub)
      response1 = RequestRegistry.instance.response_for_request(@request_signature)
      response2 = RequestRegistry.instance.response_for_request(@request_signature)
      response1.should_not be(response2)
    end

    it "should report nothing if no response for request is registered" do
      RequestRegistry.instance.response_for_request(@request_signature).should == nil
    end

    it "should always return last registered matching response" do
      @request_stub1 = RequestStub.new(:get, "www.example.com")
      @request_stub1.to_return(:body => "abc")
      @request_stub2 = RequestStub.new(:get, "www.example.com")
      @request_stub2.to_return(:body => "def")
      @request_stub3 = RequestStub.new(:get, "www.example.org")
      @request_stub3.to_return(:body => "ghj")
      RequestRegistry.instance.register_request_stub(@request_stub1)
      RequestRegistry.instance.register_request_stub(@request_stub2)
      RequestRegistry.instance.register_request_stub(@request_stub3)
      RequestRegistry.instance.response_for_request(@request_signature).should == Response.new(:body => "def")
    end

  end

  describe "times executed" do

    def times_executed(request_pattern)
      self.requested.hash.select { |executed_request_pattern, times_executed|
        executed_request_pattern.match(request_pattern)
      }.inject(0) {|sum, (_, times_executed)| sum =+ times_executed }
    end

    before(:each) do
      @request_stub1 = RequestStub.new(:get, "www.example.com")
      @request_stub2 = RequestStub.new(:get, "www.example.net")
      @request_stub3 = RequestStub.new(:get, "www.example.org")
      RequestRegistry.instance.requested_signatures.put(RequestSignature.new(:get, "www.example.com"))
      RequestRegistry.instance.requested_signatures.put(RequestSignature.new(:get, "www.example.com"))
      RequestRegistry.instance.requested_signatures.put(RequestSignature.new(:get, "www.example.org"))
    end

    it "should report 0 if no request matching pattern was requested" do
      RequestRegistry.instance.times_executed(RequestPattern.new(:get, "www.example.net")).should == 0
    end

    it "should report number of times matching pattern was requested" do
      RequestRegistry.instance.times_executed(RequestPattern.new(:get, "www.example.com")).should == 2
    end

    it "should report number of times all matching pattern were requested" do
      RequestRegistry.instance.times_executed(RequestPattern.new(:get, /.*example.*/)).should == 3
    end


  end

end
