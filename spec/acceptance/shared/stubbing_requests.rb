shared_examples_for "stubbing requests" do |*adapter_info|
  describe "when requests are stubbed" do
    describe "based on uri" do
      it "should return stubbed response even if request have escaped parameters" do
        stub_request(:get, "www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}").to_return(:body => "abc")
        http_request(:get, "http://www.example.com/hello%2B/?#{ESCAPED_PARAMS}").body.should == "abc"
      end

      it "should return stubbed response even if request has non escaped params" do
        stub_request(:get, "www.example.com/hello%2B/?#{ESCAPED_PARAMS}").to_return(:body => "abc")
        http_request(:get, "http://www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}").body.should == "abc"
      end

      it "should return stubbed response even if stub uri is declared as regexp and request params are escaped" do
        stub_request(:get, /.*x=ab c.*/).to_return(:body => "abc")
        http_request(:get, "http://www.example.com/hello/?#{ESCAPED_PARAMS}").body.should == "abc"
      end

      it "should raise error specifying stubbing instructions with escaped characters in params if there is no matching stub" do
        begin
          http_request(:get, "http://www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}")
        rescue WebMock::NetConnectNotAllowedError => e
          e.message.should match /Unregistered request: GET http:\/\/www\.example\.com\/hello\+\/\?x=ab%20c&z='Stop!'%20said%20Fred%20m/m
          e.message.should match /stub_request\(:get, "http:\/\/www\.example\.com\/hello\+\/\?x=ab%20c&z='Stop!'%20said%20Fred%20m"\)/m
        end

        stub_request(:get, "http://www.example.com/hello+/?x=ab%20c&z='Stop!'%20said%20Fred%20m")
        http_request(:get, "http://www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}")
      end
    end

    describe "based on query params" do
      it "should return stubbed response when stub declares query params as a hash" do
        stub_request(:get, "www.example.com").with(:query => {"a" => ["b x", "c d"]}).to_return(:body => "abc")
        http_request(:get, "http://www.example.com/?a[]=b+x&a[]=c%20d").body.should == "abc"
      end

      it "should return stubbed response when stub declares query params as a hash" do
        stub_request(:get, "www.example.com").with(:query => "a[]=b&a[]=c").to_return(:body => "abc")
        http_request(:get, "http://www.example.com/?a[]=b&a[]=c").body.should == "abc"
      end

      it "should return stubbed response when stub declares query params both in uri and as a hash" do
        stub_request(:get, "www.example.com/?x=3").with(:query => {"a" => ["b", "c"]}).to_return(:body => "abc")
        http_request(:get, "http://www.example.com/?x=3&a[]=b&a[]=c").body.should == "abc"
      end

      it "should return stubbed response when stub expects only part of query params" do
        stub_request(:get, "www.example.com").with(:query => hash_including({"a" => ["b", "c"]})).to_return(:body => "abc")
        http_request(:get, "http://www.example.com/?a[]=b&a[]=c&b=1").body.should == "abc"
      end
    end

    describe "based on method" do
      it "should return stubbed response" do
        stub_request(:get, "www.example.com")
        http_request(:get, "http://www.example.com/").status.should == "200"
      end

      it "should raise error if stubbed request has different method" do
        stub_request(:get, "www.example.com")
        http_request(:get, "http://www.example.com/").status.should == "200"
        lambda {
          http_request(:delete, "http://www.example.com/")
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: DELETE http://www.example.com/)
                             )
      end
    end

    describe "based on body" do
      it "should match requests if body is the same" do
        stub_request(:post, "www.example.com").with(:body => "abc")
        http_request(
          :post, "http://www.example.com/",
        :body => "abc").status.should == "200"
      end

      it "should match requests if body is not set in the stub" do
        stub_request(:post, "www.example.com")
        http_request(
          :post, "http://www.example.com/",
        :body => "abc").status.should == "200"
      end

      it "should not match requests if body is different" do
        stub_request(:post, "www.example.com").with(:body => "abc")
        lambda {
          http_request(:post, "http://www.example.com/", :body => "def")
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'def'))
      end

      describe "with regular expressions" do
        it "should match requests if body matches regexp" do
          stub_request(:post, "www.example.com").with(:body => /\d+abc$/)
          http_request(
            :post, "http://www.example.com/",
          :body => "123abc").status.should == "200"
        end

        it "should not match requests if body doesn't match regexp" do
          stub_request(:post, "www.example.com").with(:body => /^abc/)
          lambda {
            http_request(:post, "http://www.example.com/", :body => "xabc")
          }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'xabc'))
        end
      end

      describe "when body is declared as a hash" do
        before(:each) do
          stub_request(:post, "www.example.com").
            with(:body => {:a => '1', :b => 'five x', 'c' => {'d' => ['e', 'f']} })
        end

        describe "for request with url encoded body" do
          it "should match request if hash matches body" do
            http_request(
              :post, "http://www.example.com/",
            :body => 'a=1&c[d][]=e&c[d][]=f&b=five+x').status.should == "200"
          end

          it "should match request if hash matches body in different order of params" do
            http_request(
              :post, "http://www.example.com/",
            :body => 'a=1&c[d][]=e&b=five+x&c[d][]=f').status.should == "200"
          end

          it "should not match if hash doesn't match url encoded body" do
            lambda {
              http_request(
                :post, "http://www.example.com/",
              :body => 'c[d][]=f&a=1&c[d][]=e')
            }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'c\[d\]\[\]=f&a=1&c\[d\]\[\]=e'))
          end
        end


        describe "for request with json body and content type is set to json" do
          it "should match if hash matches body" do
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five x\"}").status.should == "200"
          end

          it "should match if hash matches body in different form" do
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"a\":\"1\",\"b\":\"five x\",\"c\":{\"d\":[\"e\",\"f\"]}}").status.should == "200"
          end

          it "should match if hash contains date string" do #Crack creates date object
            WebMock.reset!
            stub_request(:post, "www.example.com").
              with(:body => {"foo" => "2010-01-01"})
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"foo\":\"2010-01-01\"}").status.should == "200"
          end

          it "should match if any of the strings have spaces" do
            WebMock.reset!
            stub_request(:post, "www.example.com").with(:body => {"foo" => "a b c"})
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"foo\":\"a b c\"}").status.should == "200"
          end
        end

        describe "for request with xml body and content type is set to xml" do
          before(:each) do
            WebMock.reset!
            stub_request(:post, "www.example.com").
              with(:body => { "opt" => {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']} }})
          end

          it "should match if hash matches body" do
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
            :body => "<opt a=\"1\" b=\"five\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n").status.should == "200"
          end

          it "should match if hash matches body in different form" do
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
            :body => "<opt b=\"five\" a=\"1\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n").status.should == "200"
          end

          it "should match if hash contains date string" do #Crack creates date object
            WebMock.reset!
            stub_request(:post, "www.example.com").
              with(:body => {"opt" => {"foo" => "2010-01-01"}})
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
            :body => "<opt foo=\"2010-01-01\">\n</opt>\n").status.should == "200"
          end
        end
      end

      describe "when body is declared as partial hash matcher" do
        before(:each) do
          stub_request(:post, "www.example.com").
            with(:body => hash_including({:a => '1', 'c' => {'d' => ['e', 'f']} }))
        end

        describe "for request with url encoded body" do
          it "should match request if hash matches body" do
            http_request(
              :post, "http://www.example.com/",
            :body => 'a=1&c[d][]=e&c[d][]=f&b=five').status.should == "200"
          end

          it "should not match if hash doesn't match url encoded body" do
            lambda {
              http_request(
                :post, "http://www.example.com/",
              :body => 'c[d][]=f&a=1&c[d][]=e').status
            }.should raise_error
          end
        end

        describe "for request with json body and content type is set to json" do
          it "should match if hash matches body" do
            http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five\"}").status.should == "200"
          end
        end
      end
    end

    describe "based on headers" do
      it "should match requests if headers are the same" do
        stub_request(:get, "www.example.com").with(:headers => SAMPLE_HEADERS )
        http_request(
          :get, "http://www.example.com/",
        :headers => SAMPLE_HEADERS).status.should == "200"
      end

      it "should match requests if headers are the same and declared as array" do
        stub_request(:get, "www.example.com").with(:headers => {"a" => ["b"]} )
        http_request(
          :get, "http://www.example.com/",
        :headers => {"a" => "b"}).status.should == "200"
      end

      describe "when multiple headers with the same key are used" do
        it "should match requests if headers are the same" do
          stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]} )
          http_request(
            :get, "http://www.example.com/",
          :headers => {"a" => ["b", "c"]}).status.should == "200"
        end

        it "should match requests if headers are the same  but in different order" do
          stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]} )
          http_request(
            :get, "http://www.example.com/",
          :headers => {"a" => ["c", "b"]}).status.should == "200"
        end

        it "should not match requests if headers are different" do
          stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]})

          lambda {
            http_request(
              :get, "http://www.example.com/",
            :headers => {"a" => ["b", "d"]})
          }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
        end
      end

      it "should match requests if request headers are not stubbed" do
        stub_request(:get, "www.example.com")
        http_request(
          :get, "http://www.example.com/",
        :headers => SAMPLE_HEADERS).status.should == "200"
      end

      it "should not match requests if headers are different" do
        stub_request(:get, "www.example.com").with(:headers => SAMPLE_HEADERS)

        lambda {
          http_request(
            :get, "http://www.example.com/",
          :headers => { 'Content-Length' => '9999'})
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
      end

      it "should not match if accept header is different" do
        stub_request(:get, "www.example.com").
          with(:headers => { 'Accept' => 'application/json'})
        lambda {
          http_request(
            :get, "http://www.example.com/",
          :headers => { 'Accept' => 'application/xml'})
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
      end

      describe "declared as regular expressions" do
        it "should match requests if header values match regular expression" do
          stub_request(:get, "www.example.com").with(:headers => { :some_header => /^MyAppName$/ })
          http_request(
            :get, "http://www.example.com/",
          :headers => { 'some-header' => 'MyAppName' }).status.should == "200"
        end

        it "should not match requests if headers values do not match regular expression" do
          stub_request(:get, "www.example.com").with(:headers => { :some_header => /^MyAppName$/ })

          lambda {
            http_request(
              :get, "http://www.example.com/",
            :headers => { 'some-header' => 'xMyAppName' })
          }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
        end
      end
    end

    describe "when stubbing request with basic authentication", :unless => (adapter_info.include?(:no_url_auth)) do
      it "should match if credentials are the same" do
        stub_request(:get, "user:pass@www.example.com")
        http_request(:get, "http://user:pass@www.example.com/").status.should == "200"
      end

      it "should not match if credentials are different" do
        stub_request(:get, "user:pass@www.example.com")
        lambda {
          http_request(:get, "http://user:pazz@www.example.com/").status.should == "200"
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://user:pazz@www.example.com/))
      end

      it "should not match if credentials are stubbed but not provided in the request" do
        stub_request(:get, "user:pass@www.example.com")
        lambda {
          http_request(:get, "http://www.example.com/").status.should == "200"
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "should not match if credentials are not stubbed but exist in the request" do
        stub_request(:get, "www.example.com")
        lambda {
          http_request(:get, "http://user:pazz@www.example.com/").status.should == "200"
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://user:pazz@www.example.com/))
      end
    end

    describe "when stubbing request with a global hook" do
      after(:each) do
        WebMock::StubRegistry.instance.global_stubs.clear
      end

      it 'returns the response returned by the hook' do
        WebMock.globally_stub_request do |request|
          { :body => "global stub body" }
        end

        http_request(:get, "http://www.example.com/").body.should == "global stub body"
      end

      it 'does not get cleared when a user calls WebMock.reset!' do
        WebMock.globally_stub_request do |request|
          { :body => "global stub body" }
        end
        WebMock.reset!
        http_request(:get, "http://www.example.com/").body.should == "global stub body"
      end

      it "does not stub the request if the hook does not return anything" do
        WebMock.globally_stub_request { |r| }
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "passes the request to the block" do
        passed_request = nil
        WebMock.globally_stub_request do |request|
          passed_request = request
          { :body => "global stub body" }
        end

        http_request(:get, "http://www.example.com:456/bar")
        passed_request.uri.to_s.should == "http://www.example.com:456/bar"
      end

      it "should call the block only once per request" do
        call_count = 0
        WebMock.globally_stub_request do |request|
          call_count += 1
          { :body => "global stub body" }
        end
        http_request(:get, "http://www.example.com/")
        call_count.should == 1
      end

      it 'supports multiple global stubs; the first registered one that returns a non-nil value determines the stub' do
        stub_invocation_order = []
        WebMock.globally_stub_request do |request|
          stub_invocation_order << :nil_stub
          nil
        end

        WebMock.globally_stub_request do |request|
          stub_invocation_order << :hash_stub
          { :body => "global stub body" }
        end

        http_request(:get, "http://www.example.com/").body.should == "global stub body"
        stub_invocation_order.should eq([:nil_stub, :hash_stub])
      end

      [:before, :after].each do |before_or_after|
        context "when there is also a non-global registered stub #{before_or_after} the global stub" do
          def stub_non_globally
            stub_request(:get, "www.example.com").to_return(:body => 'non-global stub body')
          end

          define_method :register_stubs do |block|
            stub_non_globally if before_or_after == :before
            WebMock.globally_stub_request(&block)
            stub_non_globally if before_or_after == :after
          end

          it 'uses the response from the global stub if the block returns a non-nil value' do
            register_stubs(lambda { |req| { :body => 'global stub body' } })
            http_request(:get, "http://www.example.com/").body.should == "global stub body"
          end

          it 'uses the response from the non-global stub if the block returns a nil value' do
            register_stubs(lambda { |req| nil })
            http_request(:get, "http://www.example.com/").body.should == "non-global stub body"
          end
        end
      end
    end

    describe "when stubbing request with a block evaluated on request" do
      it "should match if block returns true" do
        stub_request(:get, "www.example.com").with { |request| true }
        http_request(:get, "http://www.example.com/").status.should == "200"
      end

      it "should not match if block returns false" do
        stub_request(:get, "www.example.com").with { |request| false }
        lambda {
          http_request(:get, "http://www.example.com/")
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "should pass the request to the block" do
        stub_request(:post, "www.example.com").with { |request| request.body == "wadus" }
        http_request(
          :post, "http://www.example.com/",
        :body => "wadus").status.should == "200"
        lambda {
          http_request(:post, "http://www.example.com/", :body => "jander")
        }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'jander'))
      end

      it "should call the block only once per request" do
        call_count = 0
        stub_request(:get, "www.example.com").with { |request| call_count += 1; true }
        http_request(:get, "http://www.example.com/").status.should == "200"
        call_count.should == 1
      end
    end
  end

  describe "when request stub was removed" do
    it "should raise an error on request" do
      stub = stub_request(:get, "www.example.com")

      http_request(:get, "http://www.example.com/")

      remove_request_stub(stub)

      lambda {
        http_request(:get, "http://www.example.com/")
      }.should raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
    end
  end
end
