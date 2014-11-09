require 'spec_helper'

describe WebMock::ResponseFactory do

  describe "response_for" do

    it "should create response with options passed as arguments" do
      options = {:body => "abc", :headers => {:a => :b}}
      expect(WebMock::Response).to receive(:new).with(options).and_return(@response = double(WebMock::Response))
      expect(WebMock::ResponseFactory.response_for(options)).to eq(@response)
    end


    it "should create dynamic response for argument responding to call" do
      callable = double(:call => {:body => "abc"})
      expect(WebMock::DynamicResponse).to receive(:new).with(callable).and_return(@response = double(WebMock::Response))
      expect(WebMock::ResponseFactory.response_for(callable)).to eq(@response)
    end

  end

end

describe WebMock::Response do
  before(:each) do
    @response = WebMock::Response.new(:headers => {'A' => 'a'})
  end

  it "should raise an error when initialized with unknown option" do
    expect { WebMock::Response.new(:foo => "bar") }.to raise_error('Unknown key: "foo". Valid keys are: "headers", "status", "body", "exception", "should_timeout"')
  end

  it "should report normalized headers" do
    expect(WebMock::Util::Headers).to receive(:normalize_headers).with('A' => 'a').and_return('B' => 'b')
    @response = WebMock::Response.new(:headers => {'A' => 'a'})
    expect(@response.headers).to eq({'B' => 'b'})
  end

  describe "status" do
    it "should have 200 code and empty message by default" do
      expect(@response.status).to eq([200, ""])
    end

    it "should return assigned status" do
      @response = WebMock::Response.new(:status => 500)
      expect(@response.status).to eq([500, ""])
    end

    it "should return assigned message" do
      @response = WebMock::Response.new(:status => [500, "Internal Server Error"])
      expect(@response.status).to eq([500, "Internal Server Error"])
    end
  end

  describe "raising error" do

    it "should raise error if any assigned" do
      @response = WebMock::Response.new(:exception => ArgumentError)
      expect {
        @response.raise_error_if_any
      }.to raise_error(ArgumentError, "Exception from WebMock")
    end

    it "should raise error if any assigned as instance" do
      @response = WebMock::Response.new(:exception => ArgumentError.new("hello world"))
      expect {
        @response.raise_error_if_any
      }.to raise_error(ArgumentError, "hello world")
    end

    it "should raise error if any assigned as string" do
      @response = WebMock::Response.new(:exception => "hello world")
      expect {
        @response.raise_error_if_any
      }.to raise_error("hello world")
    end

    it "should not raise error if no error assigned" do
      @response.raise_error_if_any
    end

  end

  describe "timeout" do

    it "should know if it should timeout" do
      @response = WebMock::Response.new(:should_timeout => true)
      expect(@response.should_timeout).to be_truthy
    end

    it "should not timeout by default" do
      @response = WebMock::Response.new
      expect(@response.should_timeout).to be_falsey
    end

  end

  describe "body" do

    it "should return empty body by default" do
      expect(@response.body).to eq('')
    end

    it "should report body if assigned" do
      @response = WebMock::Response.new(:body => "abc")
      expect(@response.body).to eq("abc")
    end

    it "should report string even if existing file path was provided" do
      @response = WebMock::Response.new(:body => __FILE__)
      expect(@response.body).to eq(__FILE__)
    end

    it "should report content of a IO object if provided" do
      @response = WebMock::Response.new(:body => File.new(__FILE__))
      expect(@response.body).to eq(File.read(__FILE__))
    end

    it "should report many times content of a IO object if provided" do
      @response = WebMock::Response.new(:body => File.new(__FILE__))
      expect(@response.body).to eq(File.read(__FILE__))
      expect(@response.body).to eq(File.read(__FILE__))
    end

    it "should work with Pathnames" do
      @response = WebMock::Response.new(:body => Pathname.new(__FILE__))
      expect(@response.body).to eq(File.read(__FILE__))
    end

    # Users of webmock commonly make the mistake of stubbing the response
    # body to return a hash, to prevent this:
    #
    it "should error if not given one of the allowed types" do
      expect { WebMock::Response.new(:body => Hash.new) }.to \
        raise_error(WebMock::Response::InvalidBody)
    end

  end

  describe "from raw response" do

    describe "when input is IO" do
      before(:each) do
        @file = File.new(CURL_EXAMPLE_OUTPUT_PATH)
        @response = WebMock::Response.new(@file)
      end


      it "should read status" do
        expect(@response.status).to eq([202, "OK"])
      end

      it "should read headers" do
        expect(@response.headers).to eq({
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"419",
          "Connection"=>"Keep-Alive",
          "Accept"=>"image/jpeg, image/png"
          })
      end

      it "should read body" do
        expect(@response.body.size).to eq(419)
      end

      it "should close IO" do
        expect(@file).to be_closed
      end

    end

    describe "when input is String" do
      before(:each) do
        @input = File.read(CURL_EXAMPLE_OUTPUT_PATH)
        @response = WebMock::Response.new(@input)
      end

      it "should read status" do
        expect(@response.status).to eq([202, "OK"])
      end

      it "should read headers" do
        expect(@response.headers).to eq({
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"419",
          "Connection"=>"Keep-Alive",
          "Accept"=>"image/jpeg, image/png"
          })
      end

      it "should read body" do
        expect(@response.body.size).to eq(419)
      end

      it "should work with transfer-encoding set to chunked" do
        @input.gsub!("Content-Length: 419", "Transfer-Encoding: chunked")
        @response = WebMock::Response.new(@input)
        expect(@response.body.size).to eq(419)
      end

    end

    describe "with dynamically evaluated options" do

      before(:each) do
        @request_signature = WebMock::RequestSignature.new(:post, "www.example.com", :body => "abc", :headers => {'A' => 'a'})
      end

      it "should have evaluated body" do
        @response = WebMock::Response.new(:body => lambda {|request| request.body})
        expect(@response.evaluate(@request_signature).body).to eq("abc")
      end

      it "should have evaluated headers" do
        @response = WebMock::Response.new(:headers => lambda {|request| request.headers})
        expect(@response.evaluate(@request_signature).headers).to eq({'A' => 'a'})
      end

      it "should have evaluated status" do
        @response = WebMock::Response.new(:status => lambda {|request| 302})
        expect(@response.evaluate(@request_signature).status).to eq([302, ""])
      end

    end

  end

  describe WebMock::DynamicResponse do

    describe "evaluating response options" do

      it "should evaluate new response with evaluated options" do
        request_signature = WebMock::RequestSignature.new(:post, "www.example.com", :body => "abc", :headers => {'A' => 'a'})
        response = WebMock::DynamicResponse.new(lambda {|request|
          {
            :body => request.body,
            :headers => request.headers,
            :status => 302
          }
        })
        evaluated_response = response.evaluate(request_signature)
        expect(evaluated_response.body).to eq("abc")
        expect(evaluated_response.headers).to eq({'A' => 'a'})
        expect(evaluated_response.status).to eq([302, ""])
      end

      it "should be equal to static response after evaluation" do
        request_signature = WebMock::RequestSignature.new(:post, "www.example.com", :body => "abc")
        response = WebMock::DynamicResponse.new(lambda {|request| {:body => request.body}})
        evaluated_response = response.evaluate(request_signature)
        expect(evaluated_response).to eq(WebMock::Response.new(:body => "abc"))
      end

      describe "when raw response is evaluated" do
        before(:each) do
          @files = {
            "www.example.com" => File.new(CURL_EXAMPLE_OUTPUT_PATH)
          }
          @request_signature = WebMock::RequestSignature.new(:get, "www.example.com")
        end

        describe "as a file" do
          it "should return response" do
            response = WebMock::DynamicResponse.new(lambda {|request| @files[request.uri.host.to_s] })
            expect(response.evaluate(@request_signature).body.size).to eq(419)
          end
        end

        describe "as a string" do
          it "should return response" do
            response = WebMock::DynamicResponse.new(lambda {|request| @files[request.uri.host.to_s].read })
            expect(response.evaluate(@request_signature).body.size).to eq(419)
          end
        end
      end
    end

  end

end
