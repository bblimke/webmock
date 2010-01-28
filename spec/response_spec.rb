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

    it "should report string even if existing file path was provided" do
      @response = Response.new(:body => __FILE__)
      @response.body.should == __FILE__
    end

    it "should report content of a IO object if provided" do
      @response = Response.new(:body => File.new(__FILE__))
      @response.body.should == File.new(__FILE__).read
    end

    it "should report many times content of a IO object if provided" do
      @response = Response.new(:body => File.new(__FILE__))
      @response.body.should == File.new(__FILE__).read
      @response.body.should == File.new(__FILE__).read
    end

  end

  describe "from raw response" do

    describe "when input is IO" do
      before(:each) do
        @file = File.new(File.expand_path(File.dirname(__FILE__)) + "/example_curl_output.txt")
        @response = Response.new(@file)
      end


      it "should read status" do
        @response.status.should == 200
      end

      it "should read headers" do
        @response.headers.should == {
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"438",
          "Connection"=>"Keep-Alive"
          }
      end

      it "should read body" do
        @response.body.size.should == 438
      end

      it "should close IO" do
        @file.should be_closed
      end

    end

    describe "when input is String" do
      before(:each) do
        @input = File.new(File.expand_path(File.dirname(__FILE__)) + "/example_curl_output.txt").read
        @response = Response.new(@input)
      end

      it "should read status" do
        @response.status.should == 200
      end

      it "should read headers" do
        @response.headers.should == {
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"438",
          "Connection"=>"Keep-Alive"
          }
      end

      it "should read body" do
        @response.body.size.should == 438
      end

      it "should work with transfer-encoding set to chunked" do
        @input.gsub!("Content-Length: 438", "Transfer-Encoding: chunked")
        @response = Response.new(@input)
        @response.body.size.should == 438
      end

    end

  end

end
