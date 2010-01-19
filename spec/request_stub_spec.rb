require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestStub do

  before(:each) do
    @request_stub = RequestStub.new(:get, "www.example.com")
  end

  it "should have request profile with method and uri" do
    @request_stub.request_profile.method.should == :get
    @request_stub.request_profile.uri.host.should == "www.example.com"
  end

  it "should have response" do
    @request_stub.response.should be_a(WebMock::Response)
  end

  describe "with" do

    it "should assign body to request profile" do
      @request_stub.with(:body => "abc")
      @request_stub.request_profile.body.should == RequestProfile::Body.new("abc")
    end

    it "should assign normalized headers to request profile" do
      Util::Headers.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
      @request_stub.with(:headers => {'A' => 'a'})
      @request_stub.request_profile.headers.should == {'B' => 'b'}
    end

  end

  describe "to_return" do

    it "should assign response with provided options" do
      @request_stub.to_return(:body => "abc", :status => 500)
      @request_stub.response.body.should == "abc"
      @request_stub.response.status.should == 500
    end

    it "should assign responses with provided options" do
      @request_stub.to_return([{:body => "abc"}, {:body => "def"}])
      @request_stub.responses.map {|r| r.body}.should == ["def", "abc"]
    end

  end

  describe "response" do

    it "should return responses in a sequence" do
      @request_stub.to_return([{:body => "abc"}, {:body => "def"}])
      @request_stub.response.body.should == "abc"
      @request_stub.response.body.should == "def"
    end

    it "should repeat returning last response" do
      @request_stub.to_return([{:body => "abc"}, {:body => "def"}])
      @request_stub.response
      @request_stub.response
      @request_stub.response.body.should == "def"
    end

  end

  describe "to_raise" do

    it "should assign response with exception to be thrown" do
      @request_stub.to_raise(ArgumentError)
      lambda {
        @request_stub.response.raise_error_if_any
      }.should raise_error(ArgumentError, "Exception from WebMock")
    end

    it "should assign a list responses to be thrown in a sequence" do
      @request_stub.to_raise([ArgumentError, IndexError])
      lambda {
        @request_stub.response.raise_error_if_any
      }.should raise_error(ArgumentError, "Exception from WebMock")
      lambda {
        @request_stub.response.raise_error_if_any
      }.should raise_error(IndexError, "Exception from WebMock")
    end

  end

end
