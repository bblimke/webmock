require 'spec_helper'

describe WebMock::RequestStub do

  before(:each) do
    @request_stub = WebMock::RequestStub.new(:get, "www.example.com")
  end

  it "should have request pattern with method and uri" do
    expect(@request_stub.request_pattern.to_s).to eq("GET http://www.example.com/")
  end

  it "should have response" do
    expect(@request_stub.response).to be_a(WebMock::Response)
  end

  describe "with" do

    it "should assign body to request pattern" do
      @request_stub.with(body: "abc")
      expect(@request_stub.request_pattern.to_s).to eq(WebMock::RequestPattern.new(:get, "www.example.com", body: "abc").to_s)
    end

    it "should assign normalized headers to request pattern" do
      @request_stub.with(headers: {'A' => 'a'})
      expect(@request_stub.request_pattern.to_s).to eq(
        WebMock::RequestPattern.new(:get, "www.example.com", headers: {'A' => 'a'}).to_s
      )
    end

    it "should assign given block to request profile" do
      @request_stub.with { |req| req.body == "abc" }
      expect(@request_stub.request_pattern.matches?(WebMock::RequestSignature.new(:get, "www.example.com", body: "abc"))).to be_truthy
    end

  end

  describe "to_return" do

    it "should assign response with provided options" do
      @request_stub.to_return(body: "abc", status: 500)
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.status).to eq([500, ""])
    end

    it "should assign responses with provided options" do
      @request_stub.to_return([{body: "abc"}, {body: "def"}])
      expect([@request_stub.response.body, @request_stub.response.body]).to eq(["abc", "def"])
    end

  end

  describe "to_return_json" do

    it "should raise if a block is given" do
      expect {
        @request_stub.to_return_json(body: "abc", status: 500) { puts "don't call me" }
      }.to raise_error(ArgumentError, '#to_return_json does not support passing a block')
    end

    it "should assign responses normally" do
      @request_stub.to_return_json([{body: "abc"}, {body: "def"}])
      expect([@request_stub.response.body, @request_stub.response.body]).to eq(["abc", "def"])
    end

    it "should json-ify a Hash body" do
      @request_stub.to_return_json(body: {abc: "def"}, status: 500)
      expect(@request_stub.response.body).to eq({abc: "def"}.to_json)
      expect(@request_stub.response.status).to eq([500, ""])
    end

    it "should apply the content_type header" do
      @request_stub.to_return_json(body: {abc: "def"}, status: 500)
      expect(@request_stub.response.headers).to eq({"Content-Type"=>"application/json"})
    end

    it "should preserve existing headers" do
      @request_stub.to_return_json(headers: {"A" => "a"}, body: "")
      expect(@request_stub.response.headers).to eq({"A"=>"a", "Content-Type"=>"application/json"})
    end

    it "should allow callsites to override content_type header" do
      @request_stub.to_return_json(headers: {content_type: 'application/super-special-json'})
      expect(@request_stub.response.headers).to eq({"Content-Type"=>"application/super-special-json"})
    end
  end

  describe "then" do
    it "should return stub without any modifications, acting as syntactic sugar" do
      expect(@request_stub.then).to eq(@request_stub)
    end
  end

  describe "response" do

    it "should return responses in a sequence passed as array" do
      @request_stub.to_return([{body: "abc"}, {body: "def"}])
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("def")
    end

    it "should repeat returning last response" do
      @request_stub.to_return([{body: "abc"}, {body: "def"}])
      @request_stub.response
      @request_stub.response
      expect(@request_stub.response.body).to eq("def")
    end

    it "should return responses in a sequence passed as comma separated params" do
      @request_stub.to_return({body: "abc"}, {body: "def"})
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("def")
    end

    it "should return responses declared in multiple to_return declarations" do
      @request_stub.to_return({body: "abc"}).to_return({body: "def"})
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("def")
    end

  end

  describe "to_raise" do

    it "should assign response with exception to be thrown" do
      @request_stub.to_raise(ArgumentError)
      expect {
        @request_stub.response.raise_error_if_any
      }.to raise_error(ArgumentError, "Exception from WebMock")
    end

    it "should assign sequence of responses with response with exception to be thrown" do
      @request_stub.to_return(body: "abc").then.to_raise(ArgumentError)
      expect(@request_stub.response.body).to eq("abc")
      expect {
        @request_stub.response.raise_error_if_any
      }.to raise_error(ArgumentError, "Exception from WebMock")
    end

    it "should assign a list responses to be thrown in a sequence" do
      @request_stub.to_raise(ArgumentError, IndexError)
      expect {
        @request_stub.response.raise_error_if_any
      }.to raise_error(ArgumentError, "Exception from WebMock")
      expect {
        @request_stub.response.raise_error_if_any
      }.to raise_error(IndexError, "Exception from WebMock")
    end

    it "should raise exceptions declared in multiple to_raise declarations" do
       @request_stub.to_raise(ArgumentError).then.to_raise(IndexError)
        expect {
          @request_stub.response.raise_error_if_any
        }.to raise_error(ArgumentError, "Exception from WebMock")
        expect {
          @request_stub.response.raise_error_if_any
        }.to raise_error(IndexError, "Exception from WebMock")
    end

  end

  describe "to_timeout" do

     it "should assign response with timeout" do
       @request_stub.to_timeout
       expect(@request_stub.response.should_timeout).to be_truthy
     end

     it "should assign sequence of responses with response with timeout" do
       @request_stub.to_return(body: "abc").then.to_timeout
       expect(@request_stub.response.body).to eq("abc")
       expect(@request_stub.response.should_timeout).to be_truthy
     end

     it "should allow multiple timeouts to be declared" do
       @request_stub.to_timeout.then.to_timeout.then.to_return(body: "abc")
       expect(@request_stub.response.should_timeout).to be_truthy
       expect(@request_stub.response.should_timeout).to be_truthy
       expect(@request_stub.response.body).to eq("abc")
     end

   end


  describe "times" do

    it "should give error if declared before any response declaration is declared" do
      expect {
        @request_stub.times(3)
       }.to raise_error("Invalid WebMock stub declaration. times(N) can be declared only after response declaration.")
    end

    it "should repeat returning last declared response declared number of times" do
      @request_stub.to_return({body: "abc"}).times(2).then.to_return({body: "def"})
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("def")
    end

    it "should repeat raising last declared exception declared number of times" do
      @request_stub.to_return({body: "abc"}).times(2).then.to_return({body: "def"})
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("def")
    end

    it "should repeat returning last declared sequence of responses declared number of times" do
      @request_stub.to_return({body: "abc"}, {body: "def"}).times(2).then.to_return({body: "ghj"})
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("def")
      expect(@request_stub.response.body).to eq("abc")
      expect(@request_stub.response.body).to eq("def")
      expect(@request_stub.response.body).to eq("ghj")
    end

    it "should return self" do
      expect(@request_stub.to_return({body: "abc"}).times(1)).to eq(@request_stub)
    end

    it "should raise error if argument is not integer" do
      expect {
         @request_stub.to_return({body: "abc"}).times("not number")
      }.to raise_error("times(N) accepts integers >= 1 only")
    end

    it "should raise error if argument is < 1" do
      expect {
        @request_stub.to_return({body: "abc"}).times(0)
      }.to raise_error("times(N) accepts integers >= 1 only")
    end

  end

end
