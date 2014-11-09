class MyException < StandardError; end;

shared_context "declared responses" do |*adapter_info|
  describe "when request stub declares that request should raise exception" do
    it "should raise exception" do
      stub_request(:get, "www.example.com").to_raise(MyException)
      expect {
        http_request(:get, "http://www.example.com/")
      }.to raise_error(MyException, "Exception from WebMock")
    end

    it "should raise exception if declared as and exception instance" do
      stub_request(:get, "www.example.com").to_raise(MyException.new("hello world"))
      expect {
        http_request(:get, "http://www.example.com/")
      }.to raise_error(MyException, "hello world")
    end

    it "should raise exception if declared as an exception instance" do
      stub_request(:get, "www.example.com").to_raise("hello world")
      expect {
        http_request(:get, "http://www.example.com/")
      }.to raise_error("hello world")
    end

    it "should raise exception after returning declared successful response first" do
      stub_request(:get, "www.example.com").to_return(:body => "abc").then.to_raise(MyException)
      expect(http_request(:get, "http://www.example.com/").body).to eq("abc")
      expect {
        http_request(:get, "http://www.example.com/")
      }.to raise_error(MyException, "Exception from WebMock")
    end
  end

  describe "when request stub declares that request should timeout" do
    it "should timeout" do
      stub_request(:get, "www.example.com").to_timeout
      expect {
        http_request(:get, "http://www.example.com/")
      }.to raise_error(client_timeout_exception_class)
    end

    it "should timeout after returning declared successful response" do
      stub_request(:get, "www.example.com").to_return(:body => "abc").then.to_timeout
      expect(http_request(:get, "http://www.example.com/").body).to eq("abc")
      expect {
        http_request(:get, "http://www.example.com/")
      }.to raise_error(client_timeout_exception_class)
    end
  end

  describe "when request stub declares that request should return a response" do
    it "should return response with declared body" do
      stub_request(:get, "www.example.com").to_return(:body => "abc")
      expect(http_request(:get, "http://www.example.com/").body).to eq("abc")
    end

    it "should return response with declared headers" do
      stub_request(:get, "www.example.com").to_return(:headers => SAMPLE_HEADERS)
      response = http_request(:get, "http://www.example.com/")
      expect(response.headers["Content-Length"]).to eq("8888")
    end

    it "should return response with declared headers even if there are multiple headers with the same key" do
      stub_request(:get, "www.example.com").to_return(:headers => {"a" => ["b", "c"]})
      response = http_request(:get, "http://www.example.com/")
      expect(response.headers["A"]).to eq("b, c")
    end

    it "should return response with declared status code" do
      stub_request(:get, "www.example.com").to_return(:status => 500)
      expect(http_request(:get, "http://www.example.com/").status).to eq("500")
    end

    it "should return response with declared status message", :unless => (adapter_info.include?(:no_status_message)) do
      stub_request(:get, "www.example.com").to_return(:status => [500, "Internal Server Error"])
      response = http_request(:get, "http://www.example.com/")
      expect(response.message).to eq("Internal Server Error")
    end

    it "should return response with a default status code" do
      stub_request(:get, "www.example.com")
      expect(http_request(:get, "http://www.example.com/").status).to eq("200")
    end

    it "should return default response with empty message if response was not declared", :unless => (adapter_info.include?(:no_status_message)) do
      stub_request(:get, "www.example.com")
      response = http_request(:get, "http://www.example.com/")
      expect(response.message).to eq("")
    end

    describe "when response body was declared as IO" do
      it "should return response body" do
        stub_request(:get, "www.example.com").to_return(:body => File.new(__FILE__))
        expect(http_request(:get, "http://www.example.com/").body).to eq(File.read(__FILE__))
      end

      it "should return response body if requested many times" do
        stub_request(:get, "www.example.com").to_return(:body => File.new(__FILE__))
        2.times do
          expect(http_request(:get, "http://www.example.com/").body).to eq(File.read(__FILE__))
        end
      end

      it "should close IO after request" do
        stub_request(:get, "www.example.com").to_return(:body => @file = File.new(__FILE__))
        expect(@file).to be_closed
      end
    end

    describe "when response parts were declared as lambdas" do
      it "should return evaluated response body" do
        stub_request(:post, "www.example.com").to_return(:body => lambda { |request| request.body })
        expect(http_request(:post, "http://www.example.com/", :body => "echo").body).to eq("echo")
      end

      it "should return evaluated response headers" do
        stub_request(:post, "www.example.com").to_return(:headers => lambda { |request| request.headers })
        expect(http_request(:post, "http://www.example.com/", :body => "abc", :headers => {'A' => 'B'}).headers['A']).to eq('B')
        expect(http_request(:post, "http://www.example.com/", :body => "abc", :headers => {'A' => 'C'}).headers['A']).to eq('C')
      end

      it "should evaluate response body for each request" do
        stub_request(:post, "www.example.com").to_return(:body => lambda { |request| request.body })
        expect(http_request(:post, "http://www.example.com/", :body => "echo").body).to eq("echo")
        expect(http_request(:post, "http://www.example.com/", :body => "foxtrot").body).to eq("foxtrot")
      end
    end

    describe "when response was declared as lambda" do
      class Responder
        def call(request)
          {:body => request.body}
        end
      end

      it "should return evaluated response body" do
        stub_request(:post, "www.example.com").to_return(lambda {|request|
                                                                {:body => request.body}
        })
        expect(http_request(:post, "http://www.example.com/", :body => "echo").body).to eq("echo")
        expect(http_request(:post, "http://www.example.com/", :body => "foxtrot").body).to eq("foxtrot")
      end

      it "should return evaluated response headers" do
        stub_request(:get, "www.example.com").to_return(lambda { |request|
                                                               {:headers => request.headers}
        })
        expect(http_request(:get, "http://www.example.com/", :headers => {'A' => 'B'}).headers['A']).to eq('B')
      end

      it "should return dynamic response declared as a block" do
        stub_request(:post, "www.example.com").to_return do |request|
          {:body => request.body}
        end
        expect(http_request(:post, "http://www.example.com/", :body => "echo").body).to eq("echo")
      end

      it "should return dynamic response declared as an object responding to call" do
        stub_request(:post, "www.example.com").to_return(Responder.new)
        expect(http_request(:post, "http://www.example.com/", :body => "echo").body).to eq("echo")
      end
    end


    describe "when response was declared as a file with a raw response" do
      before(:each) do
        @file = File.new(CURL_EXAMPLE_OUTPUT_PATH)
        stub_request(:get, "www.example.com").to_return(@file)
        @response = http_request(:get, "http://www.example.com/")
      end

      it "should return recorded headers" do
        expect(@response.headers).to eq({
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"419",
          "Connection"=>"Keep-Alive",
          "Accept"=>"image/jpeg, image/png"
        })
      end

      it "should return recorded body" do
        expect(@response.body.size).to eq(419)
      end

      it "should return recorded status" do
        expect(@response.status).to eq("202")
      end

      it "should return recorded status message", :unless => (adapter_info.include?(:no_status_message)) do
        expect(@response.message).to eq("OK")
      end

      it "should ensure file is closed" do
        expect(@file).to be_closed
      end
    end

    describe "when response was declared as a string with a raw response" do
      before(:each) do
        @input = File.read(CURL_EXAMPLE_OUTPUT_PATH)
        stub_request(:get, "www.example.com").to_return(@input)
        @response = http_request(:get, "http://www.example.com/")
      end

      it "should return recorded headers" do
        expect(@response.headers).to eq({
          "Date"=>"Sat, 23 Jan 2010 01:01:05 GMT",
          "Content-Type"=>"text/html; charset=UTF-8",
          "Content-Length"=>"419",
          "Connection"=>"Keep-Alive",
          "Accept"=>"image/jpeg, image/png"
        })
      end

      it "should return recorded body" do
        expect(@response.body.size).to eq(419)
      end

      it "should return recorded status" do
        expect(@response.status).to eq("202")
      end

      it "should return recorded status message", :unless => (adapter_info.include?(:no_status_message)) do
        expect(@response.message).to eq("OK")
      end
    end

    describe "when response was declared as lambda evaluating to a string with a raw response" do
      before(:each) do
        @files = {
          "www.example.com" => File.new(CURL_EXAMPLE_OUTPUT_PATH)
        }
      end

      it "should return response from evaluated file" do
        stub_request(:get, "www.example.com").to_return(lambda {|request| @files[request.uri.host.to_s] })
        expect(http_request(:get, "http://www.example.com/").body.size).to eq(419)
      end

      it "should return response from evaluated string" do
        stub_request(:get, "www.example.com").to_return(lambda {|request| @files[request.uri.host.to_s].read })
        expect(http_request(:get, "http://www.example.com/").body.size).to eq(419)
      end
    end

    describe "when response is declared as an Rack app" do
      it "should return response returned by the rack app" do
        stub_request(:any, "http://www.example.com/greet").to_rack(MyRackApp)
        expect(http_request(:post, 'http://www.example.com/greet', :body => 'name=Jimmy').body).to eq('Good to meet you, Jimmy!')
      end

      it "should pass along the port number to the rack app" do
        stub_request(:get, "http://www.example.com/compute").to_rack(MyRackApp)
        expect(http_request(:get, "http://www.example.com/compute").status).to eq("200")
      end

      it "preserves content-type header when proxying to a rack app" do
        stub_request(:any, //).to_rack(lambda {|req| [200, {}, ["OK"]] })

        url = "https://google.com/hi/there"
        headers = {
          "Accept"       => "application/json",
          "Content-Type" => "application/json"
        }

        http_request(:get, url, :headers => headers)
        expect(WebMock).to have_requested(:get, url).with(:headers => headers)
      end
    end

    describe "when sequences of responses are declared" do
      it "should return responses one by one if declared in array" do
        stub_request(:get, "www.example.com").to_return([ {:body => "1"}, {:body => "2"}, {:body => "3"} ])
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
        expect(http_request(:get, "http://www.example.com/").body).to eq("3")
      end

      it "should repeat returning last declared response from a sequence after all responses were returned" do
        stub_request(:get, "www.example.com").to_return([ {:body => "1"}, {:body => "2"} ])
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
      end

      it "should return responses one by one if declared as comma separated params" do
        stub_request(:get, "www.example.com").to_return({:body => "1"}, {:body => "2"}, {:body => "3"})
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
        expect(http_request(:get, "http://www.example.com/").body).to eq("3")
      end

      it "should return responses one by one if declared with several to_return invokations" do
        stub_request(:get, "www.example.com").
          to_return({:body => "1"}).
          to_return({:body => "2"}).
          to_return({:body => "3"})
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
        expect(http_request(:get, "http://www.example.com/").body).to eq("3")
      end

      it "should return responses one by one if declared with to_return invocations separated with then syntactic sugar" do
        stub_request(:get, "www.example.com").to_return({:body => "1"}).then.
          to_return({:body => "2"}).then.to_return({:body => "3"})
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
        expect(http_request(:get, "http://www.example.com/").body).to eq("3")
      end

    end

    describe "when responses are declared to return more than once" do
      it "should repeat one response declared number of times" do
        stub_request(:get, "www.example.com").
          to_return({:body => "1"}).times(2).
          to_return({:body => "2"})
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
      end


      it "should repeat sequence of response declared number of times" do
        stub_request(:get, "www.example.com").
          to_return({:body => "1"}, {:body => "2"}).times(2).
          to_return({:body => "3"})
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
        expect(http_request(:get, "http://www.example.com/").body).to eq("3")
      end


      it "should repeat infinitely last response even if number of declared times is lower" do
        stub_request(:get, "www.example.com").
          to_return({:body => "1"}).times(2)
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
        expect(http_request(:get, "http://www.example.com/").body).to eq("1")
      end

      it "should give error if times is declared without specifying response" do
        expect {
          stub_request(:get, "www.example.com").times(3)
        }.to raise_error("Invalid WebMock stub declaration. times(N) can be declared only after response declaration.")
      end

    end

    describe "when exception is declared to be raised more than once" do
      it "should repeat raising exception declared number of times" do
        stub_request(:get, "www.example.com").
          to_raise(MyException).times(2).
          to_return({:body => "2"})
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(MyException, "Exception from WebMock")
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(MyException, "Exception from WebMock")
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
      end

      it "should repeat raising sequence of exceptions declared number of times" do
        stub_request(:get, "www.example.com").
          to_raise(MyException, ArgumentError).times(2).
          to_return({:body => "2"})
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(MyException, "Exception from WebMock")
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(ArgumentError)
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(MyException, "Exception from WebMock")
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(ArgumentError)
        expect(http_request(:get, "http://www.example.com/").body).to eq("2")
      end
    end
  end
end
