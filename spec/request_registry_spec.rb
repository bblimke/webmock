require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe WebMock::RequestRegistry do

  before(:each) do
    WebMock::RequestRegistry.instance.reset!
    @request_pattern = WebMock::RequestPattern.new(:get, "www.example.com")
    @request_signature = WebMock::RequestSignature.new(:get, "www.example.com")
  end

  describe "reset!" do
    before(:each) do
      WebMock::RequestRegistry.instance.requested_signatures.put(@request_signature)
    end

    it "should clean list of executed requests" do
      WebMock::RequestRegistry.instance.times_executed(@request_pattern).should == 1
      WebMock::RequestRegistry.instance.reset!
      WebMock::RequestRegistry.instance.times_executed(@request_pattern).should == 0
    end

  end

  describe "times executed" do

    before(:each) do
      @request_stub1 = WebMock::RequestStub.new(:get, "www.example.com")
      @request_stub2 = WebMock::RequestStub.new(:get, "www.example.net")
      @request_stub3 = WebMock::RequestStub.new(:get, "www.example.org")
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.com"))
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.com"))
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.org"))
    end

    it "should report 0 if no request matching pattern was requested" do
      WebMock::RequestRegistry.instance.times_executed(WebMock::RequestPattern.new(:get, "www.example.net")).should == 0
    end

    it "should report number of times matching pattern was requested" do
      WebMock::RequestRegistry.instance.times_executed(WebMock::RequestPattern.new(:get, "www.example.com")).should == 2
    end

    it "should report number of times all matching pattern were requested" do
      WebMock::RequestRegistry.instance.times_executed(WebMock::RequestPattern.new(:get, /.*example.*/)).should == 3
    end


  end

end
