require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestRegistry do

  before(:each) do
    RequestRegistry.instance.reset_webmock
    @request_profile = RequestProfile.new(:get, "www.example.com")
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
      RequestRegistry.instance.times_executed(@request_profile).should == 1
      RequestRegistry.instance.reset_webmock
      RequestRegistry.instance.times_executed(@request_profile).should == 0
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

    it "should registered response for request profile" do
      @request_stub.response = @response = Response.new
      RequestRegistry.instance.register_request_stub(@request_stub)
      RequestRegistry.instance.response_for_request(@request_signature).should == @response
    end

    it "should report nothing if no response for request is registered" do
      RequestRegistry.instance.response_for_request(@request_signature).should == nil
    end

    it "should always return last registered matching response" do
      @request_stub1 = RequestStub.new(:get, "www.example.com")
      @request_stub1.response = @response1 = Response.new
      @request_stub2 = RequestStub.new(:get, "www.example.com")
      @request_stub2.response = @response2 = Response.new
      @request_stub3 = RequestStub.new(:get, "www.example.org")
      @request_stub3.response = @response3 = Response.new
      RequestRegistry.instance.register_request_stub(@request_stub1)
      RequestRegistry.instance.register_request_stub(@request_stub2)
      RequestRegistry.instance.register_request_stub(@request_stub3)
      RequestRegistry.instance.response_for_request(@request_signature).should == @response2
    end

  end

  describe "times executed" do

    def times_executed(request_profile)
      self.requested.hash.select { |executed_request_profile, times_executed|
        executed_request_profile.match(request_profile)
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

    it "should report 0 if no request matching profile was requested" do
      RequestRegistry.instance.times_executed(RequestProfile.new(:get, "www.example.net")).should == 0
    end

    it "should report number of times matching profile was requested" do
      RequestRegistry.instance.times_executed(RequestProfile.new(:get, "www.example.com")).should == 2
    end

    it "should report number of times all matching profile were requested" do
      RequestRegistry.instance.times_executed(RequestProfile.new(:get, /.*example.*/)).should == 3
    end


  end

end
