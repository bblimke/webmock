require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

unless defined? SAMPLE_HEADERS
  SAMPLE_HEADERS = { "Content-Length" => "8888", "Accept" => "application/json" }
  ESCAPED_PARAMS = "x=ab%2Bc&z=%27Stop%21%27%20said%20Fred"
  NOT_ESCAPED_PARAMS = "z='Stop!' said Fred&x=ab c"
end

describe "WebMock", :shared => true do
  before(:each) do
    WebMock.disable_net_connect!
    RequestRegistry.instance.reset_webmock
  end

  describe "when web connect" do

    describe "is allowed" do
      before(:each) do
        WebMock.allow_net_connect!
      end

      it "should make a real web request if request is not stubbed" do
        setup_expectations_for_real_example_com_request
        http_request(:get, "http://www.example.com/").
          body.should =~ /.*Google fake response.*/
      end

      it "should make a real https request if request is not stubbed" do
        setup_expectations_for_real_example_com_request(:port => 443)
        http_request(:get, "https://www.example.com/").
          body.should =~ /.*Google fake response.*/
      end

      it "should return stubbed response if request was stubbed" do
        stub_http_request(:get, "www.example.com").to_return(:body => "abc")
        http_request(:get, "http://www.example.com/").body.should == "abc"
      end
    end

    describe "is not allowed" do
      before(:each) do
        WebMock.disable_net_connect!
      end

      it "should return stubbed response if request was stubbed" do
        stub_http_request(:get, "www.example.com").to_return(:body => "abc")
        http_request(:get, "http://www.example.com/").body.should == "abc"
      end

      it "should raise exception if request was not stubbed" do
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should fail_with("Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/")
      end
    end

  end

  describe "when matching requests" do

    describe "on uri" do

      it "should match the request by uri with non escaped params if request have escaped parameters" do
        stub_http_request(:get, "www.example.com/?#{NOT_ESCAPED_PARAMS}").to_return(:body => "abc")
        http_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}").body.should == "abc"
      end

      it "should match the request by uri with escaped parameters even if request has non escaped params" do
        stub_http_request(:get, "www.example.com/?#{ESCAPED_PARAMS}").to_return(:body => "abc")
        http_request(:get, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}").body.should == "abc"
      end

      it "should match the request by regexp matching non escaped params uri if request params are escaped" do
        stub_http_request(:get, /.*x=ab c.*/).to_return(:body => "abc")
        http_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}").body.should == "abc"
      end

    end

    describe "on method" do

      it "should match the request by method if registered" do
        stub_http_request(:get, "www.example.com")
        http_request(:get, "http://www.example.com/").status.should == "200"
      end

      it "should not match requests if method is different" do
        stub_http_request(:get, "www.example.com")
        http_request(:get, "http://www.example.com/").status.should == "200"
        lambda {
          http_request(:post, "http://www.example.com/")
        }.should fail_with("Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/"
        )
      end

    end

    describe "on body" do

      it "should match requests if body is the same" do
        stub_http_request(:get, "www.example.com").with(:body => "abc")
        http_request(
          :get, "http://www.example.com/",
          :body => "abc").status.should == "200"
      end

      it "should match requests if body is not set in the stub" do
        stub_http_request(:get, "www.example.com")
        http_request(
          :get, "http://www.example.com/",
          :body => "abc").status.should == "200"
      end

      it "should not match requests if body is different" do
        stub_http_request(:get, "www.example.com").with(:body => "abc")
        lambda {
          http_request(:get, "http://www.example.com/", :body => "def")
        }.should fail_with("Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with body 'def'")
      end

      describe "with regular expressions" do

        it "should match requests if body matches regexp" do
          stub_http_request(:get, "www.example.com").with(:body => /\d+abc$/)
          http_request(
            :get, "http://www.example.com/",
            :body => "123abc").status.should == "200"
        end

        it "should not match requests if body doesn't match regexp" do
          stub_http_request(:get, "www.example.com").with(:body => /^abc/)
          lambda {
            http_request(:get, "http://www.example.com/", :body => "xabc")
          }.should fail_with("Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with body 'xabc'")
        end

      end

    end

    describe "on headers" do

      it "should match requests if headers are the same" do
        stub_http_request(:get, "www.example.com").with(:headers => SAMPLE_HEADERS )
        http_request(
          :get, "http://www.example.com/",
          :headers => SAMPLE_HEADERS).status.should == "200"
      end

      it "should match requests if request headers are not stubbed" do
        stub_http_request(:get, "www.example.com")
        http_request(
          :get, "http://www.example.com/",
          :headers => SAMPLE_HEADERS).status.should == "200"
      end

      it "should not match requests if headers are different" do
        stub_http_request(:get, "www.example.com").with(:headers => SAMPLE_HEADERS)

        lambda {
          http_request(
            :get, "http://www.example.com/",
          :headers => { 'Content-Length' => '9999'})
        }.should fail_with(%q(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers {'Content-Length'=>'9999'}))
      end

      it "should not match if accept header is different" do
        stub_http_request(:get, "www.example.com").
          with(:headers => { 'Accept' => 'application/json'})
        lambda {
          http_request(
            :get, "http://www.example.com/",
          :headers => { 'Accept' => 'application/xml'})
        }.should fail_with(%q(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers {'Accept'=>'application/xml'}))
      end
    end

    describe "with basic authentication" do

      it "should match if credentials are the same" do
        stub_http_request(:get, "user:pass@www.example.com")
        http_request(:get, "http://user:pass@www.example.com/").status.should == "200"
      end

      it "should not match if credentials are different" do
        stub_http_request(:get, "user:pass@www.example.com")
        lambda {
          http_request(:get, "http://user:pazz@www.example.com/").status.should == "200"
        }.should fail_with(%q(Real HTTP connections are disabled. Unregistered request: GET http://user:pazz@www.example.com/))
      end

      it "should not match if credentials are stubbed but not provided in the request" do
        stub_http_request(:get, "user:pass@www.example.com")
        lambda {
          http_request(:get, "http://www.example.com/").status.should == "200"
        }.should fail_with(%q(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "should not match if credentials are not stubbed but exist in the request" do
        stub_http_request(:get, "www.example.com")
        lambda {
          http_request(:get, "http://user:pazz@www.example.com/").status.should == "200"
        }.should fail_with(%q(Real HTTP connections are disabled. Unregistered request: GET http://user:pazz@www.example.com/))
      end

    end

  end

  describe "raising stubbed exceptions" do

    it "should raise exception if declared in a stubbed response" do
      class MyException < StandardError; end;
        stub_http_request(:get, "www.example.com").to_raise(MyException)
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(MyException, "Exception from WebMock")
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

      it "should return declared status" do
        stub_http_request(:get, "www.example.com").to_return(:status => 500)
        http_request(:get, "http://www.example.com/").status.should == "500"
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

      describe "dynamic responses" do

        it "should return evaluated response body" do
          stub_http_request(:post, "www.example.com").to_return(:body => lambda { |request| request.body })
          http_request(:post, "http://www.example.com/", :body => "echo").body.should == "echo"
        end

        it "should return evaluated response headers" do
          stub_http_request(:post, "www.example.com").to_return(:headers => lambda { |request| request.headers })
          http_request(:post, "http://www.example.com/", :headers => {'A' => 'B'}).headers['A'].should == 'B'
        end

      end

    end


    describe "precedence of stubs" do

      it "should use the last declared matching request stub" do
        stub_http_request(:get, "www.example.com").to_return(:body => "abc")
        stub_http_request(:get, "www.example.com").to_return(:body => "def")
        http_request(:get, "http://www.example.com/").body.should == "def"
      end

      it "should not be affected by the type of uri or request method" do
        stub_http_request(:get, "www.example.com").to_return(:body => "abc")
        stub_http_request(:any, /.*example.*/).to_return(:body => "def")
        http_request(:get, "http://www.example.com/").body.should == "def"
      end

    end

    describe "verification of request expectation" do

      describe "when net connect not allowed" do

        before(:each) do
          WebMock.disable_net_connect!
          stub_http_request(:any, "http://www.example.com")
          stub_http_request(:any, "https://www.example.com")
        end

        it "should pass if request was executed with the same uri and method" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.com").should have_been_made.once
          }.should_not raise_error
        end

        it "should pass if request was not expected and not executed" do
          lambda {
            request(:get, "http://www.example.com").should_not have_been_made
          }.should_not raise_error
        end

        it "should fail if request was not expected but executed" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.com").should_not have_been_made
          }.should fail_with("The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time")
        end


        it "should fail if request was not executed" do
          lambda {
            request(:get, "http://www.example.com").should have_been_made
          }.should fail_with("The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times")
        end

        it "should fail if request was executed to different uri" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.org").should have_been_made
          }.should fail_with("The request GET http://www.example.org/ was expected to execute 1 time but it executed 0 times")
        end

        it "should fail if request was executed with different method" do
          lambda {
            http_request(:post, "http://www.example.com/")
            request(:get, "http://www.example.com").should have_been_made
          }.should fail_with("The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times")
        end

        it "should pass if request was executed with different form of uri" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "www.example.com").should have_been_made
          }.should_not raise_error
        end

        it "should pass if request was executed with different form of uri without port " do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "www.example.com:80").should have_been_made
          }.should_not raise_error
        end

        it "should pass if request was executed with different form of uri with port" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "www.example.com:80").should have_been_made
          }.should_not raise_error
        end

        it "should fail if request was executed with different  port" do
          lambda {
            http_request(:get, "http://www.example.com:80/")
            request(:get, "www.example.com:90").should have_been_made
          }.should fail_with("The request GET http://www.example.com:90/ was expected to execute 1 time but it executed 0 times")
        end

        it "should pass if request was executed with different form of uri with https port" do
          lambda {
            http_request(:get, "https://www.example.com/")
            request(:get, "https://www.example.com:443/").should have_been_made
          }.should_not raise_error
        end

        describe "when matching requests with escaped uris" do

          before(:each) do
            WebMock.disable_net_connect!
            stub_http_request(:any, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}")
          end

          it "should pass if request was executed with escaped params" do
            lambda {
              http_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}")
              request(:get, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}").should have_been_made
            }.should_not raise_error
          end

          it "should pass if request was executed with non escaped params but escaped expected" do
            lambda {
              http_request(:get, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}")
              request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}").should have_been_made
            }.should_not raise_error
          end

          it "should pass if request was executed with escaped params but uri matichg regexp expected" do
            lambda {
              http_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}")
              request(:get, /.*example.*/).should have_been_made
            }.should_not raise_error
          end
        end

        it "should fail if requested more times than expected" do
          lambda {
            http_request(:get, "http://www.example.com/")
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.com").should have_been_made
          }.should fail_with("The request GET http://www.example.com/ was expected to execute 1 time but it executed 2 times")
        end

        it "should fail if requested less times than expected" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.com").should have_been_made.twice
          }.should fail_with("The request GET http://www.example.com/ was expected to execute 2 times but it executed 1 time")
        end

        it "should fail if requested less times than expected when 3 times expected" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.com").should have_been_made.times(3)
          }.should fail_with("The request GET http://www.example.com/ was expected to execute 3 times but it executed 1 time")
        end

        it "should succeed if request was executed with the same body" do
          lambda {
            http_request(:get, "http://www.example.com/", :body => "abc")
            request(:get, "www.example.com").with(:body => "abc").should have_been_made
          }.should_not raise_error
        end

        it "should fail if request was executed with different body" do
          lambda {
            http_request(:get, "http://www.example.com/", :body => "abc")
            request(:get, "www.example.com").
            with(:body => "def").should have_been_made
          }.should fail_with("The request GET http://www.example.com/ with body 'def' was expected to execute 1 time but it executed 0 times")
        end

        it "should succeed if request was executed with the same headers" do
          lambda {
            http_request(:get, "http://www.example.com/", :headers => SAMPLE_HEADERS)
            request(:get, "www.example.com").
            with(:headers => SAMPLE_HEADERS).should have_been_made
          }.should_not raise_error
        end

        it "should fail if request was executed with different headers" do
          lambda {
            http_request(:get, "http://www.example.com/", :headers => SAMPLE_HEADERS)
            request(:get, "www.example.com").
            with(:headers => { 'Content-Length' => '9999'}).should have_been_made
          }.should fail_with("The request GET http://www.example.com/ with headers {'Content-Length'=>'9999'} was expected to execute 1 time but it executed 0 times")
        end

        it "should fail if request was executed with less headers" do
          lambda {
            http_request(:get, "http://www.example.com/", :headers => {'A' => 'a'})
            request(:get, "www.example.com").
            with(:headers => {'A' => 'a', 'B' => 'b'}).should have_been_made
          }.should fail_with("The request GET http://www.example.com/ with headers {'A'=>'a', 'B'=>'b'} was expected to execute 1 time but it executed 0 times")
        end

        it "should succeed if request was executed with more headers" do
          lambda {
            http_request(:get, "http://www.example.com/",
              :headers => {'A' => 'a', 'B' => 'b'}
            )
            request(:get, "www.example.com").
            with(:headers => {'A' => 'a'}).should have_been_made
          }.should_not raise_error
        end

        it "should succeed if request was executed with body and headers but they were not specified in expectantion" do
          lambda {
            http_request(:get, "http://www.example.com/",
              :body => "abc",
              :headers => SAMPLE_HEADERS
            )
            request(:get, "www.example.com").should have_been_made
          }.should_not raise_error
        end


        describe "with authentication" do
          before(:each) do
            stub_http_request(:any, "http://user:pass@www.example.com")
            stub_http_request(:any, "http://user:pazz@www.example.com")
          end

          it "should succeed if succeed if request was executed with expected credentials" do
            lambda {
              http_request(:get, "http://user:pass@www.example.com/")
              request(:get, "http://user:pass@www.example.com").should have_been_made.once
            }.should_not raise_error
          end

          it "should fail if request was executed with different credentials than expected" do
            lambda {
              http_request(:get, "http://user:pass@www.example.com/")
              request(:get, "http://user:pazz@www.example.com").should have_been_made.once
            }.should fail_with("The request GET http://user:pazz@www.example.com/ was expected to execute 1 time but it executed 0 times")
          end

          it "should fail if request was executed without credentials but credentials were expected" do
            lambda {
              http_request(:get, "http://www.example.com/")
              request(:get, "http://user:pass@www.example.com").should have_been_made.once
            }.should fail_with("The request GET http://user:pass@www.example.com/ was expected to execute 1 time but it executed 0 times")
          end

          it "should fail if request was executed with credentials but expected without" do
            lambda {
              http_request(:get, "http://user:pass@www.example.com/")
              request(:get, "http://www.example.com").should have_been_made.once
            }.should fail_with("The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times")
          end

        end

        describe "using webmock matcher" do

          it "should verify expected requests occured" do
            lambda {
              http_request(:get, "http://www.example.com/")
              WebMock.should have_requested(:get, "http://www.example.com").once
            }.should_not raise_error
          end

          it "should verify expected requests occured" do
            lambda {
              http_request(:get, "http://www.example.com/", :body => "abc", :headers => {'A' => 'a'})
              WebMock.should have_requested(:get, "http://www.example.com").with(:body => "abc", :headers => {'A' => 'a'}).once
            }.should_not raise_error
          end

          it "should verify that non expected requests didn't occur" do
            lambda {
              http_request(:get, "http://www.example.com/")
              WebMock.should_not have_requested(:get, "http://www.example.com")
            }.should fail_with("The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time")
          end
        end



        describe "using assert_requested" do

          it "should verify expected requests occured" do
            lambda {
              http_request(:get, "http://www.example.com/")
              assert_requested(:get, "http://www.example.com", :times => 1)
              assert_requested(:get, "http://www.example.com")
            }.should_not raise_error
          end

          it "should verify expected requests occured" do
            lambda {
              http_request(:get, "http://www.example.com/", :body => "abc", :headers => {'A' => 'a'})
              assert_requested(:get, "http://www.example.com", :body => "abc", :headers => {'A' => 'a'})
            }.should_not raise_error
          end

          it "should verify that non expected requests didn't occur" do
            lambda {
              http_request(:get, "http://www.example.com/")
              assert_not_requested(:get, "http://www.example.com")
            }.should fail_with("The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time")
          end
        end
      end


      describe "when net connect allowed" do
        before(:each) do
          WebMock.allow_net_connect!
        end

        it "should verify expected requests occured" do
          setup_expectations_for_real_example_com_request
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.com").should have_been_made
          }.should_not raise_error
        end

        it "should verify that non expected requests didn't occur" do
          lambda {
            http_request(:get, "http://www.example.com/")
            request(:get, "http://www.example.com").should_not have_been_made
          }.should fail_with("The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time")
        end
      end

    end

  end
