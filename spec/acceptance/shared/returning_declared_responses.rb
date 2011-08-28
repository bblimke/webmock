class MyException < StandardError; end;

shared_examples_for "returning declared responses" do
  describe "raising declared exceptions" do
    it "should raise exception if declared" do
      stub_http_request(:get, "www.example.com").to_raise(MyException)
      lambda {
        http_request(:get, "http://www.example.com/")
      }.should raise_error(MyException, "Exception from WebMock")
    end

    it "should raise exception if declared as and exception instance" do
      stub_http_request(:get, "www.example.com").to_raise(MyException.new("hello world"))
      lambda {
        http_request(:get, "http://www.example.com/")
      }.should raise_error(MyException, "hello world")
    end

    it "should raise exception if declared as an exception instance" do
      stub_http_request(:get, "www.example.com").to_raise("hello world")
      lambda {
        http_request(:get, "http://www.example.com/")
      }.should raise_error("hello world")
    end

    it "should raise exception if after returning declared successful response" do
      stub_http_request(:get, "www.example.com").to_return(:body => "abc").then.to_raise(MyException)
      http_request(:get, "http://www.example.com/").body.should == "abc"
      lambda {
        http_request(:get, "http://www.example.com/")
      }.should raise_error(MyException, "Exception from WebMock")
    end
  end

  describe "raising timeout errors" do
    it "should raise timeout if declared" do
      stub_http_request(:get, "www.example.com").to_timeout
      lambda {
        http_request(:get, "http://www.example.com/")
      }.should raise_error(client_timeout_exception_class)
    end

    it "should raise timeout if declared after returning declared successful response" do
      stub_http_request(:get, "www.example.com").to_return(:body => "abc").then.to_timeout
      http_request(:get, "http://www.example.com/").body.should == "abc"
      lambda {
        http_request(:get, "http://www.example.com/")
      }.should raise_error(client_timeout_exception_class)
    end
  end

  describe "returning stubbed responses" do
    it "should return declared body" do
      stub_http_request(:get, "www.example.com").to_return(:body => "abc")
      http_request(:get, "http://www.example.com/").body.should == "abc"
    end

    it "should return declared headers" do
      stub_http_request(:get, "www.example.com").to_return(:headers => SAMPLE_HEADERS)
      response = http_request(:get, "http://www.example.com/")
      response.headers["Content-Length"].should == "8888"
    end

    it "should return declared headers when there are multiple headers with the same key" do
      stub_http_request(:get, "www.example.com").to_return(:headers => {"a" => ["b", "c"]})
      response = http_request(:get, "http://www.example.com/")
      response.headers["A"].should == "b, c"
    end

    it "should return declared status code" do
      stub_http_request(:get, "www.example.com").to_return(:status => 500)
      http_request(:get, "http://www.example.com/").status.should == "500"
    end

    it "should return declared status message" do
      stub_http_request(:get, "www.example.com").to_return(:status => [500, "Internal Server Error"])
      response = http_request(:get, "http://www.example.com/")
      # not supported by em-http-request, it always returns "unknown" for http_reason
      unless http_library == :em_http_request
        response.message.should == "Internal Server Error"
      end
    end

    it "should return default status code" do
      stub_http_request(:get, "www.example.com")
      http_request(:get, "http://www.example.com/").status.should == "200"
    end

    it "should return default empty message" do
      stub_http_request(:get, "www.example.com")
      response = http_request(:get, "http://www.example.com/")
      # not supported by em-http-request, it always returns "unknown" for http_reason
      unless http_library == :em_http_request
        response.message.should == ""
      end
    end

    it "should return body declared as IO" do
      stub_http_request(:get, "www.example.com").to_return(:body => File.new(__FILE__))
      http_request(:get, "http://www.example.com/").body.should == File.new(__FILE__).read
    end

    it "should return body declared as IO if requested many times" do
      stub_http_request(:get, "www.example.com").to_return(:body => File.new(__FILE__))
      2.times do
        http_request(:get, "http://www.example.com/").body.should == File.new(__FILE__).read
      end
    end

    it "should close IO declared as response body after reading" do
      stub_http_request(:get, "www.example.com").to_return(:body => @file = File.new(__FILE__))
      @file.should be_closed
    end

    describe "when using dynamic response parts" do
      it "should return evaluated response body" do
        stub_http_request(:post, "www.example.com").to_return(:body => lambda { |request| request.body })
        http_request(:post, "http://www.example.com/", :body => "echo").body.should == "echo"
      end

      it "should return evaluated response headers" do
        stub_http_request(:post, "www.example.com").to_return(:headers => lambda { |request| request.headers })
        http_request(:post, "http://www.example.com/", :body => "abc", :headers => {'A' => 'B'}).headers['A'].should == 'B'
      end
    end

    describe "when using dynamic responses" do
      class Responder
        def call(request)
          {:body => request.body}
        end
      end

      it "should return evaluated response body" do
        stub_http_request(:post, "www.example.com").to_return(lambda {|request|
                                                                {:body => request.body}
        })
        http_request(:post, "http://www.example.com/", :body => "echo").body.should == "echo"
      end

      it "should return evaluated response headers" do
        stub_http_request(:get, "www.example.com").to_return(lambda { |request|
                                                               {:headers => request.headers}
        })
        http_request(:get, "http://www.example.com/", :headers => {'A' => 'B'}).headers['A'].should == 'B'
      end

      it "should return dynamic response declared as a blocks" do
        stub_http_request(:post, "www.example.com").to_return do |request|
          {:body => request.body}
        end
        http_request(:post, "http://www.example.com/", :body => "echo").body.should == "echo"
      end

      it "should return dynamic response declared as an object responding to call" do
        stub_http_request(:post, "www.example.com").to_return(Responder.new)
        http_request(:post, "http://www.example.com/", :body => "echo").body.should == "echo"
      end
    end


    describe "replying raw responses from file" do
      before(:each) do
        @file = File.new(CURL_EXAMPLE_OUTPUT_PATH)
        stub_http_request(:get, "www.example.com").to_return(@file)
        @response = http_request(:get, "http://www.example.com/")
      end

      it "should return recorded headers" do
        @response.headers.should == {
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"419",
          "Connection"=>"Keep-Alive",
          "Accept"=>"image/jpeg, image/png"
        }
      end

      it "should return recorded body" do
        @response.body.size.should == 419
      end

      it "should return recorded status" do
        @response.status.should == "202"
      end

      it "should return recorded status message" do
        # not supported by em-http-request, it always returns "unknown" for http_reason
        unless http_library == :em_http_request
          @response.message.should == "OK"
        end
      end

      it "should ensure file is closed" do
        @file.should be_closed
      end
    end

    describe "replying responses raw responses from string" do
      before(:each) do
        @input = File.new(CURL_EXAMPLE_OUTPUT_PATH).read
        stub_http_request(:get, "www.example.com").to_return(@input)
        @response = http_request(:get, "http://www.example.com/")
      end

      it "should return recorded headers" do
        @response.headers.should == {
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"419",
          "Connection"=>"Keep-Alive",
          "Accept"=>"image/jpeg, image/png"
        }
      end

      it "should return recorded body" do
        @response.body.size.should == 419
      end

      it "should return recorded status" do
        @response.status.should == "202"
      end

      it "should return recorded status message" do
        # not supported by em-http-request, it always returns "unknown" for http_reason
        unless http_library == :em_http_request
          @response.message.should == "OK"
        end
      end
    end

    describe "replying raw responses evaluated dynamically" do
      before(:each) do
        @files = {
          "www.example.com" => File.new(CURL_EXAMPLE_OUTPUT_PATH)
        }
      end

      it "should return response from evaluated file" do
        stub_http_request(:get, "www.example.com").to_return(lambda {|request| @files[request.uri.host.to_s] })
        http_request(:get, "http://www.example.com/").body.size.should == 419
      end

      it "should return response from evaluated string" do
        stub_http_request(:get, "www.example.com").to_return(lambda {|request| @files[request.uri.host.to_s].read })
        http_request(:get, "http://www.example.com/").body.size.should == 419
      end
    end

    describe "rack responses" do
      before(:each) do
        stub_request(:any, "http://www.example.com/greet").to_rack(MyRackApp)
      end

      it "should return response returned by rack app" do
        http_request(:post, 'http://www.example.com/greet', :body => 'name=Jimmy').body.should == 'Good to meet you, Jimmy!'
      end
    end

    describe "sequences of responses" do
      it "should return responses one by one if declared in array" do
        stub_http_request(:get, "www.example.com").to_return([ {:body => "1"}, {:body => "2"}, {:body => "3"} ])
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
        http_request(:get, "http://www.example.com/").body.should == "3"
      end

      it "should repeat returning last declared response from a sequence after all responses were returned" do
        stub_http_request(:get, "www.example.com").to_return([ {:body => "1"}, {:body => "2"} ])
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
        http_request(:get, "http://www.example.com/").body.should == "2"
      end

      it "should return responses one by one if declared as comma separated params" do
        stub_http_request(:get, "www.example.com").to_return({:body => "1"}, {:body => "2"}, {:body => "3"})
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
        http_request(:get, "http://www.example.com/").body.should == "3"
      end

      it "should return responses one by one if declared with several to_return invokations" do
        stub_http_request(:get, "www.example.com").
          to_return({:body => "1"}).
          to_return({:body => "2"}).
          to_return({:body => "3"})
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
        http_request(:get, "http://www.example.com/").body.should == "3"
      end

      it "should return responses one by one if declared with to_return invocations separated with then syntactic sugar" do
        stub_http_request(:get, "www.example.com").to_return({:body => "1"}).then.
          to_return({:body => "2"}).then.to_return({:body => "3"})
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
        http_request(:get, "http://www.example.com/").body.should == "3"
      end

    end

    describe "repeating declared responses more than once" do

      it "should repeat one response declared number of times" do
        stub_http_request(:get, "www.example.com").
          to_return({:body => "1"}).times(2).
          to_return({:body => "2"})
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
      end


      it "should repeat sequence of response declared number of times" do
        stub_http_request(:get, "www.example.com").
          to_return({:body => "1"}, {:body => "2"}).times(2).
          to_return({:body => "3"})
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "2"
        http_request(:get, "http://www.example.com/").body.should == "3"
      end


      it "should repeat infinitely last response even if number of declared times is lower" do
        stub_http_request(:get, "www.example.com").
          to_return({:body => "1"}).times(2)
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "1"
        http_request(:get, "http://www.example.com/").body.should == "1"
      end

      it "should give error if times is declared without specifying response" do
        lambda {
          stub_http_request(:get, "www.example.com").times(3)
        }.should raise_error("Invalid WebMock stub declaration. times(N) can be declared only after response declaration.")
      end

    end

    describe "raising declared exceptions more than once" do

      it "should repeat raising exception declared number of times" do
        stub_http_request(:get, "www.example.com").
          to_raise(MyException).times(2).
          to_return({:body => "2"})
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(MyException, "Exception from WebMock")
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(MyException, "Exception from WebMock")
        http_request(:get, "http://www.example.com/").body.should == "2"
      end

      it "should repeat raising sequence of exceptions declared number of times" do
        stub_http_request(:get, "www.example.com").
          to_raise(MyException, ArgumentError).times(2).
          to_return({:body => "2"})
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(MyException, "Exception from WebMock")
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(ArgumentError)
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(MyException, "Exception from WebMock")
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(ArgumentError)
        http_request(:get, "http://www.example.com/").body.should == "2"
      end
    end
  end
end
