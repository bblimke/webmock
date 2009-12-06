require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe Response do
  before(:each) do
    @response = Response.new(:headers => {'A' => 'a'})
  end

  it "should report normalized headers" do
    Util::Headers.should_receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
    @response = Response.new(:headers => {'A' => 'a'})
    @response.headers.should == {'B' => 'b'}
  end

  describe "status" do

    it "should be 200 by default" do
      @response.status.should == 200
    end

    it "should return assigned status" do
      @response = Response.new(:status => 500)
      @response.status.should == 500
    end

  end

  describe "raising error" do

    it "should raise error if any assigned" do
      @response = Response.new(:exception => ArgumentError)
      lambda {
        @response.raise_error_if_any
      }.should raise_error(ArgumentError, "Exception from WebMock")
    end

    it "should not raise error if no error assigned" do
      @response.raise_error_if_any
    end
    
  end

  describe "body" do
    
    it "should return empty body by default" do
      @response.body.should == ''
    end

    it "should report body if assigned" do
      @response = Response.new(:body => "abc")
      @response.body.should == "abc"
    end
    
    it "should report content of a file as body if provided" do
      @response = Response.new(:body => __FILE__)
      @response.body.should == File.new(__FILE__).read
    end
    
  end
  
end
