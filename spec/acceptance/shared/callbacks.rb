shared_examples_for "callbacks" do
  describe "after_request" do
    before(:each) do
      WebMock.reset_callbacks
      stub_request(:get, "http://www.example.com")
    end

    it "should not invoke callback unless request is made" do
      WebMock.after_request {
        @called = true
      }
      @called.should == nil
    end

    it "should invoke a callback after request is made" do
      WebMock.after_request {
        @called = true
      }
      http_request(:get, "http://www.example.com/")
      @called.should == true
    end

    it "should not invoke a callback if specific http library should be ignored" do
      WebMock.after_request(:except => [http_library()]) {
        @called = true
      }
      http_request(:get, "http://www.example.com/")
      @called.should == nil
    end

    it "should invoke a callback even if other http libraries should be ignored" do
      WebMock.after_request(:except => [:other_lib]) {
        @called = true
      }
      http_request(:get, "http://www.example.com/")
      @called.should == true
    end

    it "should pass request signature to the callback" do
      WebMock.after_request(:except => [:other_lib])  do |request_signature, _|
        @request_signature = request_signature
      end
      http_request(:get, "http://www.example.com/")
      @request_signature.uri.to_s.should == "http://www.example.com:80/"
    end

    describe "passing response to callback" do
      describe "for stubbed requests" do
        before(:each) do
          stub_request(:get, "http://www.example.com").
          to_return(
            :status => ["200", "hello"],
            :headers => {'Content-Length' => '666', 'Hello' => 'World'},
            :body => "foo bar"
          )
          WebMock.after_request(:except => [:other_lib])  do |_, response|
            @response = response
          end
          http_request(:get, "http://www.example.com/")
        end

        it "should pass response with status and message" do
          @response.status.should == ["200", "hello"]
        end

        it "should pass response with headers" do
          @response.headers.should == {
            'Content-Length' => '666',
            'Hello' => 'World'
          }
        end

        it "should pass response with body" do
          @response.body.should == "foo bar"
        end
      end

      describe "for real requests", :net_connect => true do
        before(:each) do
          WebMock.reset!
          WebMock.allow_net_connect!
          WebMock.after_request(:except => [:other_lib])  do |_, response|
            @response = response
          end
          http_request(:get, "http://www.example.com/")
        end

        it "should pass response with status and message" do
          # not supported by em-http-request, it always returns "unknown" for http_reason
          unless http_library == :em_http_request
            @response.status[0].should == 302
            @response.status[1].should == "Found"
          end
        end

        it "should pass response with headers" do
          @response.headers["Content-Length"].should == "0"
        end

        it "should pass response with body" do
          @response.body.size.should == 0
        end
      end
    end

    it "should invoke multiple callbacks in order of their declarations" do
      WebMock.after_request { @called = 1 }
      WebMock.after_request { @called += 1 }
      http_request(:get, "http://www.example.com/")
      @called.should == 2
    end

    it "should invoke callbacks only for real requests if requested", :net_connect => true do
      WebMock.after_request(:real_requests_only => true) { @called = true }
      http_request(:get, "http://www.example.com/")
      @called.should == nil
      WebMock.allow_net_connect!
      http_request(:get, "http://www.example.net/")
      @called.should == true
    end

    it "should clear all declared callbacks on reset callbacks" do
      WebMock.after_request { @called = 1 }
      WebMock.reset_callbacks
      stub_request(:get, "http://www.example.com/")
      http_request(:get, "http://www.example.com/")
      @called.should == nil
    end
  end
end
