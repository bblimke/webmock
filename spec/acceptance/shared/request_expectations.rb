shared_examples_for "verifying request expectations" do

  describe "when net connect not allowed" do
    before(:each) do
      WebMock.disable_net_connect!
      stub_http_request(:any, "http://www.example.com")
      stub_http_request(:any, "https://www.example.com")
    end

    it "should pass if request was executed with the same uri and method" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should have_been_made.once
      }.should_not raise_error
    end

    it "should accept verification as WebMock class method invocation" do
      lambda {
        http_request(:get, "http://www.example.com/")
        WebMock.request(:get, "http://www.example.com").should have_been_made.once
      }.should_not raise_error
    end

    it "should pass if request was not expected and not executed" do
      lambda {
        a_request(:get, "http://www.example.com").should_not have_been_made
      }.should_not raise_error
    end

    it "should fail if request was not expected but executed" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should_not have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time))
    end

    it "should fail with message with executed requests listed" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should_not have_been_made
      }.should fail_with(%r{The following requests were made:\n\nGET http://www.example.com/.+was made 1 time})
    end

    it "should fail if request was not executed" do
      lambda {
        a_request(:get, "http://www.example.com").should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times))
    end

    it "should fail if request was executed to different uri" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.org").should have_been_made
      }.should fail_with(%r(The request GET http://www.example.org/ was expected to execute 1 time but it executed 0 times))
    end

    it "should fail if request was executed with different method" do
      lambda {
        http_request(:post, "http://www.example.com/", :body => "abc")
        a_request(:get, "http://www.example.com").should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times))
    end

    it "should pass if request was executed with different form of uri" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "www.example.com").should have_been_made
      }.should_not raise_error
    end

    it "should pass if request was executed with different form of uri without port " do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "www.example.com:80").should have_been_made
      }.should_not raise_error
    end

    it "should pass if request was executed with different form of uri with port" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "www.example.com:80").should have_been_made
      }.should_not raise_error
    end

    it "should fail if request was executed with different  port" do
      lambda {
        http_request(:get, "http://www.example.com:80/")
        a_request(:get, "www.example.com:90").should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com:90/ was expected to execute 1 time but it executed 0 times))
    end

    it "should pass if request was executed with different form of uri with https port" do
      lambda {
        http_request(:get, "https://www.example.com/")
        a_request(:get, "https://www.example.com:443/").should have_been_made
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
          a_request(:get, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}").should have_been_made
        }.should_not raise_error
      end

      it "should pass if request was executed with non escaped params but escaped expected" do
        lambda {
          http_request(:get, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}")
          a_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}").should have_been_made
        }.should_not raise_error
      end

      it "should pass if request was executed with escaped params but uri matichg regexp expected" do
        lambda {
          http_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}")
          a_request(:get, /.*example.*/).should have_been_made
        }.should_not raise_error
      end

    end

    describe "when matching requests with query params" do
      before(:each) do
        stub_http_request(:any, /.*example.*/)
      end

      it "should pass if the request was executed with query params declared in a hash in query option" do
        lambda {
          http_request(:get, "http://www.example.com/?a[]=b&a[]=c")
          a_request(:get, "www.example.com").with(:query => {"a" => ["b", "c"]}).should have_been_made
        }.should_not raise_error
      end

      it "should pass if the request was executed with query params declared as string in query option" do
        lambda {
          http_request(:get, "http://www.example.com/?a[]=b&a[]=c")
          a_request(:get, "www.example.com").with(:query => "a[]=b&a[]=c").should have_been_made
        }.should_not raise_error
      end

      it "should pass if the request was executed with query params both in uri and in query option" do
        lambda {
          http_request(:get, "http://www.example.com/?x=3&a[]=b&a[]=c")
          a_request(:get, "www.example.com/?x=3").with(:query => {"a" => ["b", "c"]}).should have_been_made
        }.should_not raise_error
      end
    end

    it "should fail if requested more times than expected" do
      lambda {
        http_request(:get, "http://www.example.com/")
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 2 times))
    end

    it "should fail if requested less times than expected" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should have_been_made.twice
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 2 times but it executed 1 time))
    end

    it "should fail if requested less times than expected when 3 times expected" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should have_been_made.times(3)
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 3 times but it executed 1 time))
    end

    it "should succeed if request was executed with the same body" do
      lambda {
        http_request(:post, "http://www.example.com/", :body => "abc")
        a_request(:post, "www.example.com").with(:body => "abc").should have_been_made
      }.should_not raise_error
    end

    it "should fail if request was executed with different body" do
      lambda {
        http_request(:get, "http://www.example.com/", :body => "abc")
        a_request(:get, "www.example.com").
        with(:body => "def").should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ with body "def" was expected to execute 1 time but it executed 0 times))
    end

    describe "when expected body is declared as regexp" do

      it "should succeed if request was executed with the same body" do
        lambda {
          http_request(:post, "http://www.example.com/", :body => "abc")
          a_request(:post, "www.example.com").with(:body => /^abc$/).should have_been_made
        }.should_not raise_error
      end

      it "should fail if request was executed with different body" do
        lambda {
          http_request(:get, "http://www.example.com/", :body => "abc")
          a_request(:get, "www.example.com").
          with(:body => /^xabc/).should have_been_made
        }.should fail_with(%r(The request GET http://www.example.com/ with body /\^xabc/ was expected to execute 1 time but it executed 0 times))
      end

    end

    describe "when expected body is declared as a hash" do
      let(:body_hash) { {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']}} }
      let(:fail_message) {%r(The request POST http://www.example.com/ with body \{"a"=>"1", "b"=>"five", "c"=>\{"d"=>\["e", "f"\]\}\} was expected to execute 1 time but it executed 0 times)}

      describe "when request is executed with url encoded body matching hash" do

        it "should succeed" do
          lambda {
            http_request(:post, "http://www.example.com/", :body => 'a=1&c[d][]=e&c[d][]=f&b=five')
            a_request(:post, "www.example.com").with(:body => body_hash).should have_been_made
          }.should_not raise_error
        end

        it "should succeed if url encoded params have different order" do
          lambda {
            http_request(:post, "http://www.example.com/", :body => 'a=1&c[d][]=e&b=five&c[d][]=f')
            a_request(:post, "www.example.com").with(:body => body_hash).should have_been_made
          }.should_not raise_error
        end

        it "should fail if request is executed with url encoded body not matching hash" do
          lambda {
            http_request(:post, "http://www.example.com/", :body => 'c[d][]=f&a=1&c[d][]=e')
            a_request(:post, "www.example.com").with(:body => body_hash).should have_been_made
          }.should fail_with(fail_message)
        end

      end

      describe "when request is executed with json body matching hash and content type is set to json" do

        it "should succeed" do
          lambda {
            http_request(:post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
                         :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five\"}")
            a_request(:post, "www.example.com").with(:body => body_hash).should have_been_made
          }.should_not raise_error
        end

        it "should succeed if json body is in different form" do
          lambda {
            http_request(:post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
                         :body => "{\"a\":\"1\",\"b\":\"five\",\"c\":{\"d\":[\"e\",\"f\"]}}")
            a_request(:post, "www.example.com").with(:body => body_hash).should have_been_made
          }.should_not raise_error
        end

        it "should succeed if json body contains date string" do
          lambda {
            http_request(:post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
                         :body => "{\"foo\":\"2010-01-01\"}")
            a_request(:post, "www.example.com").with(:body => {"foo" => "2010-01-01"}).should have_been_made
          }.should_not raise_error
        end
      end


      describe "when request is executed with xml body matching hash and content type is set to xml" do
        let(:body_hash) { { "opt" => {:a => "1", :b => 'five', 'c' => {'d' => ['e', 'f']}} }}

        it "should succeed" do
          lambda {
            http_request(:post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
                         :body => "<opt a=\"1\" b=\"five\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n")
            a_request(:post, "www.example.com").with(:body => body_hash).should have_been_made
          }.should_not raise_error
        end

        it "should succeed if xml body is in different form" do
          lambda {
            http_request(:post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
                         :body => "<opt b=\"five\" a=\"1\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n")
            a_request(:post, "www.example.com").with(:body => body_hash).should have_been_made
          }.should_not raise_error
        end

        it "should succeed if xml body contains date string" do
          lambda {
            http_request(:post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
                         :body => "<opt foo=\"2010-01-01\">\n</opt>\n")
            a_request(:post, "www.example.com").with(:body => {"opt" => {"foo" => "2010-01-01"}}).should have_been_made
          }.should_not raise_error
        end

      end

    end

    it "should succeed if request was executed with the same headers" do
      lambda {
        http_request(:get, "http://www.example.com/", :headers => SAMPLE_HEADERS)
        a_request(:get, "www.example.com").
        with(:headers => SAMPLE_HEADERS).should have_been_made
      }.should_not raise_error
    end

    it "should succeed if request was executed with the same headers with value declared as array" do
      lambda {
        http_request(:get, "http://www.example.com/", :headers => {"a" => "b"})
        a_request(:get, "www.example.com").
        with(:headers => {"a" => ["b"]}).should have_been_made
      }.should_not raise_error
    end

    describe "when multiple headers with the same key are passed" do

      it "should succeed if request was executed with the same headers" do
        lambda {
          http_request(:get, "http://www.example.com/", :headers => {"a" => ["b", "c"]})
          a_request(:get, "www.example.com").
          with(:headers =>  {"a" => ["b", "c"]}).should have_been_made
        }.should_not raise_error
      end

      it "should succeed if request was executed with the same headers but different order" do
        lambda {
          http_request(:get, "http://www.example.com/", :headers => {"a" => ["b", "c"]})
          a_request(:get, "www.example.com").
          with(:headers =>  {"a" => ["c", "b"]}).should have_been_made
        }.should_not raise_error
      end

      it "should fail if request was executed with different headers" do
        lambda {
          http_request(:get, "http://www.example.com/", :headers => {"a" => ["b", "c"]})
          a_request(:get, "www.example.com").
          with(:headers => {"a" => ["b", "d"]}).should have_been_made
        }.should fail_with(%r(The request GET http://www.example.com/ with headers \{'A'=>\['b', 'd'\]\} was expected to execute 1 time but it executed 0 times))
      end

    end

    it "should fail if request was executed with different headers" do
      lambda {
        http_request(:get, "http://www.example.com/", :headers => SAMPLE_HEADERS)
        a_request(:get, "www.example.com").
        with(:headers => { 'Content-Length' => '9999'}).should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ with headers \{'Content-Length'=>'9999'\} was expected to execute 1 time but it executed 0 times))
    end

    it "should fail if request was executed with less headers" do
      lambda {
        http_request(:get, "http://www.example.com/", :headers => {'A' => 'a'})
        a_request(:get, "www.example.com").
        with(:headers => {'A' => 'a', 'B' => 'b'}).should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ with headers \{'A'=>'a', 'B'=>'b'\} was expected to execute 1 time but it executed 0 times))
    end

    it "should succeed if request was executed with more headers" do
      lambda {
        http_request(:get, "http://www.example.com/",
                     :headers => {'A' => 'a', 'B' => 'b'}
                     )
        a_request(:get, "www.example.com").
        with(:headers => {'A' => 'a'}).should have_been_made
      }.should_not raise_error
    end

    it "should succeed if request was executed with body and headers but they were not specified in expectantion" do
      lambda {
        http_request(:get, "http://www.example.com/",
                     :body => "abc",
                     :headers => SAMPLE_HEADERS
                     )
        a_request(:get, "www.example.com").should have_been_made
      }.should_not raise_error
    end

    it "should succeed if request was executed with headers matching regular expressions" do
      lambda {
        http_request(:get, "http://www.example.com/", :headers => { 'some-header' => 'MyAppName' })
        a_request(:get, "www.example.com").
        with(:headers => { :some_header => /^MyAppName$/ }).should have_been_made
      }.should_not raise_error
    end

    it "should fail if request was executed with headers not matching regular expression" do
      lambda {
        http_request(:get, "http://www.example.com/", :headers => { 'some-header' => 'xMyAppName' })
        a_request(:get, "www.example.com").
        with(:headers => { :some_header => /^MyAppName$/ }).should have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ with headers \{'Some-Header'=>/\^MyAppName\$/\} was expected to execute 1 time but it executed 0 times))
    end

    it "should suceed if request was executed and block evaluated to true" do
      lambda {
        http_request(:post, "http://www.example.com/", :body => "wadus")
        a_request(:post, "www.example.com").with { |req| req.body == "wadus" }.should have_been_made
      }.should_not raise_error
    end

    it "should fail if request was executed and block evaluated to false" do
      lambda {
        http_request(:post, "http://www.example.com/", :body => "abc")
        a_request(:post, "www.example.com").with { |req| req.body == "wadus" }.should have_been_made
      }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
    end

    it "should fail if request was not expected but it executed and block matched request" do
      lambda {
        http_request(:post, "http://www.example.com/", :body => "wadus")
        a_request(:post, "www.example.com").with { |req| req.body == "wadus" }.should_not have_been_made
      }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 0 times but it executed 1 time))
    end

    describe "with authentication" do
      before(:each) do
        stub_http_request(:any, "http://user:pass@www.example.com")
        stub_http_request(:any, "http://user:pazz@www.example.com")
      end

      it "should succeed if succeed if request was executed with expected credentials" do
        lambda {
          http_request(:get, "http://user:pass@www.example.com/")
          a_request(:get, "http://user:pass@www.example.com").should have_been_made.once
        }.should_not raise_error
      end

      it "should fail if request was executed with different credentials than expected" do
        lambda {
          http_request(:get, "http://user:pass@www.example.com/")
          a_request(:get, "http://user:pazz@www.example.com").should have_been_made.once
        }.should fail_with(%r(The request GET http://user:pazz@www.example.com/ was expected to execute 1 time but it executed 0 times))
      end

      it "should fail if request was executed without credentials but credentials were expected" do
        lambda {
          http_request(:get, "http://www.example.com/")
          a_request(:get, "http://user:pass@www.example.com").should have_been_made.once
        }.should fail_with(%r(The request GET http://user:pass@www.example.com/ was expected to execute 1 time but it executed 0 times))
      end

      it "should fail if request was executed with credentials but expected without" do
        lambda {
          http_request(:get, "http://user:pass@www.example.com/")
          a_request(:get, "http://www.example.com").should have_been_made.once
        }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times))
      end

      it "should be order insensitive" do
        stub_request(:post, "http://www.example.com")
        http_request(:post, "http://www.example.com/", :body => "def")
        http_request(:post, "http://www.example.com/", :body => "abc")
        WebMock.should have_requested(:post, "www.example.com").with(:body => "abc")
        WebMock.should have_requested(:post, "www.example.com").with(:body => "def")
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
          http_request(:post, "http://www.example.com/", :body => "abc", :headers => {'A' => 'a'})
          WebMock.should have_requested(:post, "http://www.example.com").with(:body => "abc", :headers => {'A' => 'a'}).once
        }.should_not raise_error
      end

      it "should verify that non expected requests didn't occur" do
        lambda {
          http_request(:get, "http://www.example.com/")
          WebMock.should_not have_requested(:get, "http://www.example.com")
        }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time))
      end

      it "should succeed if request was executed and block evaluated to true" do
        lambda {
          http_request(:post, "http://www.example.com/", :body => "wadus")
          WebMock.should have_requested(:post, "www.example.com").with { |req| req.body == "wadus" }
        }.should_not raise_error
      end

      it "should fail if request was executed and block evaluated to false" do
        lambda {
          http_request(:post, "http://www.example.com/", :body => "abc")
          WebMock.should have_requested(:post, "www.example.com").with { |req| req.body == "wadus" }
        }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
      end

      it "should fail if request was not expected but executed and block matched request" do
        lambda {
          http_request(:post, "http://www.example.com/", :body => "wadus")
          WebMock.should_not have_requested(:post, "www.example.com").with { |req| req.body == "wadus" }
        }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 0 times but it executed 1 time))
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
          http_request(:post, "http://www.example.com/", :body => "abc", :headers => {'A' => 'a'})
          assert_requested(:post, "http://www.example.com", :body => "abc", :headers => {'A' => 'a'})
        }.should_not raise_error
      end

      it "should verify that non expected requests didn't occur" do
        lambda {
          http_request(:get, "http://www.example.com/")
          assert_not_requested(:get, "http://www.example.com")
        }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time))
      end

      it "should verify if non expected request executed and block evaluated to true" do
        lambda {
          http_request(:post, "http://www.example.com/", :body => "wadus")
          assert_not_requested(:post, "www.example.com") { |req| req.body == "wadus" }
        }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 0 times but it executed 1 time))
      end

      it "should verify if request was executed and block evaluated to true" do
        lambda {
          http_request(:post, "http://www.example.com/", :body => "wadus")
          assert_requested(:post, "www.example.com") { |req| req.body == "wadus" }
        }.should_not raise_error
      end

      it "should verify if request was executed and block evaluated to false" do
        lambda {
          http_request(:post, "http://www.example.com/", :body => "abc")
          assert_requested(:post, "www.example.com") { |req| req.body == "wadus" }
        }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
      end
    end
  end


  describe "using matchers on the RequestStub" do
    it "should verify expected requests occured" do
      stub = stub_request(:get, "http://www.example.com/")
      http_request(:get, "http://www.example.com/")
      stub.should have_been_requested.once
    end

    it "should verify subsequent requests" do
      stub = stub_request(:get, "http://www.example.com/")
      http_request(:get, "http://www.example.com/")
      stub.should have_been_requested.once
      http_request(:get, "http://www.example.com/")
      stub.should have_been_requested.twice
    end

    it "should verify expected requests occured" do
      stub = stub_request(:post, "http://www.example.com").with(:body => "abc", :headers => {'A' => 'a'})
      http_request(:post, "http://www.example.com/", :body => "abc", :headers => {'A' => 'a'})
      stub.should have_been_requested.once
    end

    it "should verify that non expected requests didn't occur" do
      lambda {
        stub = stub_request(:get, "http://www.example.com")
        http_request(:get, "http://www.example.com/")
        stub.should_not have_been_requested
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time))
    end

    it "should verify if non expected request executed and block evaluated to true" do
      lambda {
        stub = stub_request(:post, "www.example.com").with { |req| req.body == "wadus" }
        http_request(:post, "http://www.example.com/", :body => "wadus")
        stub.should_not have_been_requested
      }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 0 times but it executed 1 time))
    end

    it "should verify if request was executed and block evaluated to true" do
      stub = stub_request(:post, "www.example.com").with { |req| req.body == "wadus" }
      http_request(:post, "http://www.example.com/", :body => "wadus")
      stub.should have_been_requested
    end

    it "should verify if request was executed and block evaluated to false" do
      lambda {
        stub_request(:any, /.+/) #stub any request
        stub = stub_request(:post, "www.example.com").with { |req| req.body == "wadus" }
        http_request(:post, "http://www.example.com/", :body => "abc")
        stub.should have_been_requested
      }.should fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
    end
  end

  describe "when net connect allowed", :net_connect => true do
    before(:each) do
      WebMock.allow_net_connect!
    end

    it "should verify expected requests occured" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should have_been_made
      }.should_not raise_error
    end

    it "should verify that non expected requests didn't occur" do
      lambda {
        http_request(:get, "http://www.example.com/")
        a_request(:get, "http://www.example.com").should_not have_been_made
      }.should fail_with(%r(The request GET http://www.example.com/ was expected to execute 0 times but it executed 1 time))
    end
  end
end
