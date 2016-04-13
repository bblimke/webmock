# encoding: utf-8

shared_examples_for "stubbing requests" do |*adapter_info|
  describe "when requests are stubbed" do
    describe "based on uri" do
      it "should return stubbed response even if request have escaped parameters" do
        stub_request(:get, "www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/hello%2B/?#{ESCAPED_PARAMS}").body).to eq("abc")
      end

      it "should return stubbed response even if query params have integer values" do
        stub_request(:get, "www.example.com").with(:query => {"a" => 1}).to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/?a=1").body).to eq("abc")
      end

      it "should return stubbed response even if request has non escaped params" do
        stub_request(:get, "www.example.com/hello%2B/?#{ESCAPED_PARAMS}").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}").body).to eq("abc")
      end

      it "should return stubbed response for url with non utf query params", "ruby>1.9" => true do
        param = 'aäoöuü'.encode('iso-8859-1')
        param = CGI.escape(param)
        stub_request(:get, "www.example.com/?#{param}").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/?#{param}").body).to eq("abc")
      end

      it "should return stubbed response even if stub uri is declared as regexp and request params are escaped" do
        stub_request(:get, /.*x=ab c.*/).to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/hello/?#{ESCAPED_PARAMS}").body).to eq("abc")
      end

      it "should raise error specifying stubbing instructions with escaped characters in params if there is no matching stub" do
        begin
          http_request(:get, "http://www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}")
        rescue WebMock::NetConnectNotAllowedError => e
          expect(e.message).to match /Unregistered request: GET http:\/\/www\.example\.com\/hello\+\/\?x=ab%20c&z='Stop!'%20said%20Fred%20m/m
          expect(e.message).to match /stub_request\(:get, "http:\/\/www\.example\.com\/hello\+\/\?x=ab%20c&z='Stop!'%20said%20Fred%20m"\)/m
        end

        stub_request(:get, "http://www.example.com/hello+/?x=ab%20c&z='Stop!'%20said%20Fred%20m")
        http_request(:get, "http://www.example.com/hello+/?#{NOT_ESCAPED_PARAMS}")
      end
    end

    describe "based on query params" do
      it "should return stubbed response when stub declares query params as a hash" do
        stub_request(:get, "www.example.com").with(:query => {"a" => ["b x", "c d"]}).to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/?a[]=b+x&a[]=c%20d").body).to eq("abc")
      end

      it "should return stubbed response when stub declares query params as a hash" do
        stub_request(:get, "www.example.com").with(:query => "a[]=b&a[]=c").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/?a[]=b&a[]=c").body).to eq("abc")
      end

      it "should return stubbed response when stub declares query params both in uri and as a hash" do
        stub_request(:get, "www.example.com/?x=3").with(:query => {"a" => ["b", "c"]}).to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/?x=3&a[]=b&a[]=c").body).to eq("abc")
      end

      it "should return stubbed response when stub expects only part of query params" do
        stub_request(:get, "www.example.com").with(:query => hash_including({"a" => ["b", "c"]})).to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/?a[]=b&a[]=c&b=1").body).to eq("abc")
      end
    end

    describe "based on method" do
      it "should return stubbed response" do
        stub_request(:get, "www.example.com")
        expect(http_request(:get, "http://www.example.com/").status).to eq("200")
      end

      it "should match stubbed request when http request was made with method given as string" do
        stub_request(:get, "www.example.com")
        expect(http_request('get', "http://www.example.com/").status).to eq("200")
      end

      it "should raise error if stubbed request has different method" do
        stub_request(:get, "www.example.com")
        expect(http_request(:get, "http://www.example.com/").status).to eq("200")
        expect {
          http_request(:delete, "http://www.example.com/")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: DELETE http://www.example.com/)
                             )
      end
    end

    describe "based on body" do
      it "should match requests if body is the same" do
        stub_request(:post, "www.example.com").with(:body => "abc")
        expect(http_request(
          :post, "http://www.example.com/",
        :body => "abc").status).to eq("200")
      end

      it "should match requests if body is not set in the stub" do
        stub_request(:post, "www.example.com")
        expect(http_request(
          :post, "http://www.example.com/",
        :body => "abc").status).to eq("200")
      end

      it "should not match requests if body is different" do
        stub_request(:post, "www.example.com").with(:body => "abc")
        expect {
          http_request(:post, "http://www.example.com/", :body => "def")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'def'))
      end

      describe "with regular expressions" do
        it "should match requests if body matches regexp" do
          stub_request(:post, "www.example.com").with(:body => /\d+abc$/)
          expect(http_request(
            :post, "http://www.example.com/",
          :body => "123abc").status).to eq("200")
        end

        it "should not match requests if body doesn't match regexp" do
          stub_request(:post, "www.example.com").with(:body => /^abc/)
          expect {
            http_request(:post, "http://www.example.com/", :body => "xabc")
          }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'xabc'))
        end
      end

      describe "when body is declared as a hash" do
        before(:each) do
          stub_request(:post, "www.example.com").
            with(:body => {:a => '1', :b => 'five x', 'c' => {'d' => ['e', 'f']} })
        end

        describe "for request with url encoded body" do
          it "should match request if hash matches body" do
            expect(http_request(
              :post, "http://www.example.com/",
            :body => 'a=1&c[d][]=e&c[d][]=f&b=five+x').status).to eq("200")
          end

          it "should match request if hash matches body in different order of params" do
            expect(http_request(
              :post, "http://www.example.com/",
            :body => 'a=1&c[d][]=e&b=five+x&c[d][]=f').status).to eq("200")
          end

          it "should not match if hash doesn't match url encoded body" do
            expect {
              http_request(
                :post, "http://www.example.com/",
              :body => 'c[d][]=f&a=1&c[d][]=e')
            }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'c\[d\]\[\]=f&a=1&c\[d\]\[\]=e'))
          end
        end


        describe "for request with json body and content type is set to json" do
          it "should match if hash matches body" do
            expect(http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five x\"}").status).to eq("200")
          end

          it "should match if hash matches body in different form" do
            expect(http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"a\":\"1\",\"b\":\"five x\",\"c\":{\"d\":[\"e\",\"f\"]}}").status).to eq("200")
          end

          it "should match if hash contains date string" do #Crack creates date object
            WebMock.reset!
            stub_request(:post, "www.example.com").
              with(:body => {"foo" => "2010-01-01"})
            expect(http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"foo\":\"2010-01-01\"}").status).to eq("200")
          end

          it "should match if any of the strings have spaces" do
            WebMock.reset!
            stub_request(:post, "www.example.com").with(:body => {"foo" => "a b c"})
            expect(http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
            :body => "{\"foo\":\"a b c\"}").status).to eq("200")
          end
        end

        describe "for request with xml body and content type is set to xml" do
          before(:each) do
            WebMock.reset!
            stub_request(:post, "www.example.com").
              with(:body => { "opt" => {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']} }})
          end

          it "should match if hash matches body" do
            expect(http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
            :body => "<opt a=\"1\" b=\"five\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n").status).to eq("200")
          end

          it "should match if hash matches body in different form" do
            expect(http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
            :body => "<opt b=\"five\" a=\"1\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n").status).to eq("200")
          end

          it "should match if hash contains date string" do #Crack creates date object
            WebMock.reset!
            stub_request(:post, "www.example.com").
              with(:body => {"opt" => {"foo" => "2010-01-01"}})
            expect(http_request(
              :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/xml'},
            :body => "<opt foo=\"2010-01-01\">\n</opt>\n").status).to eq("200")
          end
        end
      end

      describe "when body is declared as partial hash matcher" do
        subject(:request) { http_request( :post, "http://www.example.com/",
                                :body => 'a=1&c[d][]=e&c[d][]=f&b=five') }

        subject(:wrong_request) { http_request(:post, "http://www.example.com/",
                                      :body => 'c[d][]=f&a=1&c[d][]=e').status }

        describe "when using 'RSpec:Mocks::ArgumentMatchers#hash_including'" do
          before(:each) do
            stub_request(:post, "www.example.com").
              with(:body => hash_including(:a, :c => {'d' => ['e', 'f']} ))
          end

          describe "for request with url encoded body" do
            it "should match request if hash matches body" do
              expect(request.status).to eq("200")
            end

            it "should not match if hash doesn't match url encoded body" do
              expect { wrong_request }.to raise_error(WebMock::NetConnectNotAllowedError)
            end
          end

          describe "for request with json body and content type is set to json" do
            it "should match if hash matches body" do
              expect(http_request(
                :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
              :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five\"}").status).to eq("200")
            end
          end
        end

        describe "when using 'WebMock::API#hash_including'" do
          before(:each) do
            stub_request(:post, "www.example.com").
              with(:body => WebMock::API.hash_including(:a, :c => {'d' => ['e', 'f']} ))
          end

          describe "for request with url encoded body" do
            it "should match request if hash matches body" do
              expect(request.status).to eq("200")
            end

            it "should not match if hash doesn't match url encoded body" do
              expect { wrong_request }.to raise_error(WebMock::NetConnectNotAllowedError)
            end
          end

          describe "for request with json body and content type is set to json" do
            it "should match if hash matches body" do
              expect(http_request(
                :post, "http://www.example.com/", :headers => {'Content-Type' => 'application/json'},
              :body => "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five\"}").status).to eq("200")
            end
          end
        end

      end
    end

    describe "based on headers" do
      it "should match requests if headers are the same" do
        stub_request(:get, "www.example.com").with(:headers => SAMPLE_HEADERS )
        expect(http_request(
          :get, "http://www.example.com/",
        :headers => SAMPLE_HEADERS).status).to eq("200")
      end

      it "should match requests if headers are the same and declared as array" do
        stub_request(:get, "www.example.com").with(:headers => {"a" => ["b"]} )
        expect(http_request(
          :get, "http://www.example.com/",
        :headers => {"a" => "b"}).status).to eq("200")
      end

      describe "when multiple headers with the same key are used" do
        it "should match requests if headers are the same" do
          stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]} )
          expect(http_request(
            :get, "http://www.example.com/",
          :headers => {"a" => ["b", "c"]}).status).to eq("200")
        end

        it "should match requests if headers are the same  but in different order" do
          stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]} )
          expect(http_request(
            :get, "http://www.example.com/",
          :headers => {"a" => ["c", "b"]}).status).to eq("200")
        end

        it "should not match requests if headers are different" do
          stub_request(:get, "www.example.com").with(:headers => {"a" => ["b", "c"]})

          expect {
            http_request(
              :get, "http://www.example.com/",
            :headers => {"a" => ["b", "d"]})
          }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
        end
      end

      it "should match requests if request headers are not stubbed" do
        stub_request(:get, "www.example.com")
        expect(http_request(
          :get, "http://www.example.com/",
        :headers => SAMPLE_HEADERS).status).to eq("200")
      end

      it "should not match requests if headers are different" do
        stub_request(:get, "www.example.com").with(:headers => SAMPLE_HEADERS)

        expect {
          http_request(
            :get, "http://www.example.com/",
          :headers => { 'Content-Length' => '9999'})
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
      end

      it "should not match if accept header is different" do
        stub_request(:get, "www.example.com").
          with(:headers => { 'Accept' => 'application/json'})
        expect {
          http_request(
            :get, "http://www.example.com/",
          :headers => { 'Accept' => 'application/xml'})
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
      end

      describe "declared as regular expressions" do
        it "should match requests if header values match regular expression" do
          stub_request(:get, "www.example.com").with(:headers => { :some_header => /^MyAppName$/ })
          expect(http_request(
            :get, "http://www.example.com/",
          :headers => { 'some-header' => 'MyAppName' }).status).to eq("200")
        end

        it "should not match requests if headers values do not match regular expression" do
          stub_request(:get, "www.example.com").with(:headers => { :some_header => /^MyAppName$/ })

          expect {
            http_request(
              :get, "http://www.example.com/",
            :headers => { 'some-header' => 'xMyAppName' })
          }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/ with headers))
        end
      end
    end

    describe "when stubbing request with basic authentication", :unless => (adapter_info.include?(:no_url_auth)) do
      it "should match if credentials are the same" do
        stub_request(:get, "user:pass@www.example.com")
        expect(http_request(:get, "http://user:pass@www.example.com/").status).to eq("200")
      end

      it "should not match if credentials are different" do
        stub_request(:get, "user:pass@www.example.com")
        expect {
          expect(http_request(:get, "http://user:pazz@www.example.com/").status).to eq("200")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://user:pazz@www.example.com/))
      end

      it "should not match if credentials are stubbed but not provided in the request" do
        stub_request(:get, "user:pass@www.example.com")
        expect {
          expect(http_request(:get, "http://www.example.com/").status).to eq("200")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "should not match if credentials are not stubbed but exist in the request" do
        stub_request(:get, "www.example.com")
        expect {
          expect(http_request(:get, "http://user:pazz@www.example.com/").status).to eq("200")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://user:pazz@www.example.com/))
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

        expect(http_request(:get, "http://www.example.com/").body).to eq("global stub body")
      end

      it 'does not get cleared when a user calls WebMock.reset!' do
        WebMock.globally_stub_request do |request|
          { :body => "global stub body" }
        end
        WebMock.reset!
        expect(http_request(:get, "http://www.example.com/").body).to eq("global stub body")
      end

      it "does not stub the request if the hook does not return anything" do
        WebMock.globally_stub_request { |r| }
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "passes the request to the block" do
        passed_request = nil
        WebMock.globally_stub_request do |request|
          passed_request = request
          { :body => "global stub body" }
        end

        http_request(:get, "http://www.example.com:456/bar")
        expect(passed_request.uri.to_s).to eq("http://www.example.com:456/bar")
      end

      it "should call the block only once per request" do
        call_count = 0
        WebMock.globally_stub_request do |request|
          call_count += 1
          { :body => "global stub body" }
        end
        http_request(:get, "http://www.example.com/")
        expect(call_count).to eq(1)
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

        expect(http_request(:get, "http://www.example.com/").body).to eq("global stub body")
        expect(stub_invocation_order).to eq([:nil_stub, :hash_stub])
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
            expect(http_request(:get, "http://www.example.com/").body).to eq("global stub body")
          end

          it 'uses the response from the non-global stub if the block returns a nil value' do
            register_stubs(lambda { |req| nil })
            expect(http_request(:get, "http://www.example.com/").body).to eq("non-global stub body")
          end
        end
      end
    end

    describe "when stubbing request with a block evaluated on request" do
      it "should match if block returns true" do
        stub_request(:get, "www.example.com").with { |request| true }
        expect(http_request(:get, "http://www.example.com/").status).to eq("200")
      end

      it "should not match if block returns false" do
        stub_request(:get, "www.example.com").with { |request| false }
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "should pass the request to the block" do
        stub_request(:post, "www.example.com").with { |request| request.body == "wadus" }
        expect(http_request(
          :post, "http://www.example.com/",
        :body => "wadus").status).to eq("200")
        expect {
          http_request(:post, "http://www.example.com/", :body => "jander")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: POST http://www.example.com/ with body 'jander'))
      end

      it "should call the block only once per request" do
        call_count = 0
        stub_request(:get, "www.example.com").with { |request| call_count += 1; true }
        expect(http_request(:get, "http://www.example.com/").status).to eq("200")
        expect(call_count).to eq(1)
      end
    end
  end

  describe "when request stub was removed" do
    it "should raise an error on request" do
      stub = stub_request(:get, "www.example.com")

      http_request(:get, "http://www.example.com/")

      remove_request_stub(stub)

      expect {
        http_request(:get, "http://www.example.com/")
      }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
    end
  end
end
