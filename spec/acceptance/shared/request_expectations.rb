shared_context "request expectations" do |*adapter_info|
  describe "when request expectations are set" do
    describe "when net connect is not allowed" do
      before(:each) do
        WebMock.disable_net_connect!
        stub_request(:any, "http://www.example.com")
        stub_request(:any, "https://www.example.com")
      end

      it "should satisfy expectation if request was executed with the same uri and method" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).to have_been_made.once
        }.not_to raise_error
      end

      it "should satisfy expectation declared on WebMock.resuest" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(WebMock.request(:get, "http://www.example.com")).to have_been_made.once
        }.not_to raise_error
      end

      it "should satisfy expectation if request was not expected and not executed" do
        expect {
          expect(a_request(:get, "http://www.example.com")).not_to have_been_made
        }.not_to raise_error
      end

      it "should fail if request was not expected but executed" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).not_to have_been_made
        }.to fail_with(%r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time))
      end

      it "should fail resulting with failure with a message and executed requests listed" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).not_to have_been_made
        }.to fail_with(%r{The following requests were made:\n\nGET http://www.example.com/.+was made 1 time})
      end

      it "should fail if request was not executed" do
        expect {
          expect(a_request(:get, "http://www.example.com")).to have_been_made
        }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times))
      end

      it "should fail if request was executed to different uri" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.org")).to have_been_made
        }.to fail_with(%r(The request GET http://www.example.org/ was expected to execute 1 time but it executed 0 times))
      end

      it "should fail if request was executed with different method" do
        expect {
          http_request(:post, "http://www.example.com/", body: "abc")
          expect(a_request(:get, "http://www.example.com")).to have_been_made
        }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times))
      end

      it "should satisfy expectation if request was executed with different form of uri" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "www.example.com")).to have_been_made
        }.not_to raise_error
      end

      it "should satisfy expectation if request was executed with different form of uri without port " do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "www.example.com:80")).to have_been_made
        }.not_to raise_error
      end

      it "should satisfy expectation if request was executed with different form of uri with port" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "www.example.com:80")).to have_been_made
        }.not_to raise_error
      end

      it "should fail if request was executed to a different port" do
        expect {
          http_request(:get, "http://www.example.com:80/")
          expect(a_request(:get, "www.example.com:90")).to have_been_made
        }.to fail_with(%r(The request GET http://www.example.com:90/ was expected to execute 1 time but it executed 0 times))
      end

      it "should satisfy expectation if request was executed with different form of uri with https port" do
        expect {
          http_request(:get, "https://www.example.com/")
          expect(a_request(:get, "https://www.example.com:443/")).to have_been_made
        }.not_to raise_error
      end

      it "should satisfy expectations even if requests were executed in different order than expectations were declared" do
        stub_request(:post, "http://www.example.com")
        http_request(:post, "http://www.example.com/", body: "def")
        http_request(:post, "http://www.example.com/", body: "abc")
        expect(WebMock).to have_requested(:post, "www.example.com").with(body: "abc")
        expect(WebMock).to have_requested(:post, "www.example.com").with(body: "def")
      end

      describe "when matching requests with escaped or unescaped uris" do
        before(:each) do
          WebMock.disable_net_connect!
          stub_request(:any, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}")
        end

        it "should satisfy expectation if request was executed with escaped params" do
          expect {
            http_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}")
            expect(a_request(:get, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}")).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if request was executed with non escaped params" do
          expect {
            http_request(:get, "http://www.example.com/?#{NOT_ESCAPED_PARAMS}")
            expect(a_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}")).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if request was executed with escaped params and uri matching regexp was expected" do
          expect {
            http_request(:get, "http://www.example.com/?#{ESCAPED_PARAMS}")
            expect(a_request(:get, /.*example.*/)).to have_been_made
          }.not_to raise_error
        end

      end

      describe "when matching requests with query params" do
        before(:each) do
          stub_request(:any, /.*example.*/)
        end

        it "should satisfy expectation if the request was executed with query params declared as a hash in a query option" do
          expect {
            http_request(:get, "http://www.example.com/?a[]=b&a[]=c")
            expect(a_request(:get, "www.example.com").with(query: {"a" => ["b", "c"]})).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if the request was executed with query params declared as string in query option" do
          expect {
            http_request(:get, "http://www.example.com/?a[]=b&a[]=c")
            expect(a_request(:get, "www.example.com").with(query: "a[]=b&a[]=c")).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if the request was executed with query params both in uri and in query option" do
          expect {
            http_request(:get, "http://www.example.com/?x=3&a[]=b&a[]=c")
            expect(a_request(:get, "www.example.com/?x=3").with(query: {"a" => ["b", "c"]})).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if the request was executed with only part query params declared as a hash in a query option" do
          expect {
            http_request(:get, "http://www.example.com/?a[]=b&a[]=c&b=1")
            expect(a_request(:get, "www.example.com").with(query: hash_including({"a" => ["b", "c"]}))).to have_been_made
          }.not_to raise_error
        end

        it 'should satisfy expectation if the request was executed with excluding part of query params declared as a hash in a query option' do
          expect {
            http_request(:get, "http://www.example.com/?a[]=d&b[]=e&b=1")
            expect(a_request(:get, "www.example.com").with(query: hash_excluding(a: ['b', 'c']))).to have_been_made
          }.not_to raise_error
        end

        it 'should satisfy expectation if the request was executed with an empty array in the query params' do
          expect {
            http_request(:get, "http://www.example.com/?a[]")
            expect(a_request(:get, "www.example.com").with(query: hash_including(a: []))).to have_been_made
          }.not_to raise_error
        end
      end

      context "when using flat array notation" do
        before :all do
          WebMock::Config.instance.query_values_notation = :flat_array
        end

        it "should satisfy expectation if request includes different repeated query params in flat array notation" do
          expect {
            stub_request(:get, "http://www.example.com/?a=1&a=2")
            http_request(:get, "http://www.example.com/?a=1&a=2")
            expect(a_request(:get, "http://www.example.com/?a=1&a=2")).to have_been_made
          }.not_to raise_error
        end

        after :all do
          WebMock::Config.instance.query_values_notation = nil
        end
      end



      describe "at_most_times" do
        it "fails if request was made more times than maximum" do
          expect {
            http_request(:get, "http://www.example.com/")
            http_request(:get, "http://www.example.com/")
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_times(2)
          }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute at most 2 times but it executed 3 times))
        end

        it "passes if request was made the maximum number of times" do
          expect {
            http_request(:get, "http://www.example.com/")
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_times(2)
          }.not_to raise_error
        end

        it "passes if request was made fewer than the maximum number of times" do
          expect {
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_times(2)
          }.not_to raise_error
        end

        it "passes if request was not made at all" do
          expect {
            expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_times(2)
          }.not_to raise_error
        end
      end


      describe "at_least_times" do
        it "fails if request was made fewer times than minimum" do
          expect {
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_times(2)
          }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute at least 2 times but it executed 1 time))
        end

        it "passes if request was made the minimum number of times" do
          expect {
            http_request(:get, "http://www.example.com/")
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_times(2)
          }.not_to raise_error
        end

        it "passes if request was made more than the minimum number of times" do
          expect {
            http_request(:get, "http://www.example.com/")
            http_request(:get, "http://www.example.com/")
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_times(2)
          }.not_to raise_error
        end

        context "descriptive at_most_ matcher" do
          context "at_most_once" do
            it "succeeds if no request was executed" do
              expect {
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_once
              }.not_to raise_error
            end

            it "satisfies expectation if request was executed with the same uri and method once" do
              expect {
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_once
              }.not_to raise_error
            end

            it "fails if request was executed with the same uri and method twice" do
              expect {
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_once
              }.to fail
            end
          end

          context "at_most_twice" do
            it "succeeds if no request was executed" do
              expect {
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_twice
              }.not_to raise_error
            end

            it "succeeds if too few requests were executed" do
              expect {
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_twice
              }.not_to raise_error
            end

            it "satisfies expectation if request was executed with the same uri and method twice" do
              expect {
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_twice
              }.not_to raise_error
            end

            it "fails if request was executed with the same uri and method three times" do
              expect {
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_most_twice
              }.to fail
            end
          end
        end

        context "descriptive at_least_ matcher" do
          context "at_least_once" do
            it "fails if no request was executed" do
              expect {
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_once
              }.to fail
            end

            it "satisfies expectation if request was executed with the same uri and method once" do
              expect {
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_once
              }.not_to raise_error
            end

            it "satisfies expectation if request was executed with the same uri and method twice" do
              expect {
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_once
              }.not_to raise_error
            end
          end

          context "at_least_twice" do
            it "fails if no request was executed" do
              expect {
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_twice
              }.to fail
            end

            it "fails if too few requests were executed" do
              expect {
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_twice
              }.to fail
            end

            it "satisfies expectation if request was executed with the same uri and method twice" do
              expect {
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_twice
              }.not_to raise_error
            end

            it "satisfies expectation if request was executed with the same uri and method three times" do
              expect {
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                http_request(:get, "http://www.example.com/")
                expect(a_request(:get, "http://www.example.com")).to have_been_made.at_least_twice
              }.not_to raise_error
            end
          end
        end
      end

      it "should fail if request was made more times than expected" do
        expect {
          http_request(:get, "http://www.example.com/")
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).to have_been_made
        }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 2 times))
      end

      it "should fail if request was made less times than expected" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).to have_been_made.twice
        }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute 2 times but it executed 1 time))
      end

      it "should fail if request was made less times than expected when 3 times expected" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).to have_been_made.times(3)
        }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute 3 times but it executed 1 time))
      end

      it "should satisfy expectation if request was executed with the same body" do
        expect {
          http_request(:post, "http://www.example.com/", body: "abc")
          expect(a_request(:post, "www.example.com").with(body: "abc")).to have_been_made
        }.not_to raise_error
      end

      it "should fail if request was executed with different body" do
        expect {
          http_request(:post, "http://www.example.com/", body: "abc")
          expect(a_request(:post, "www.example.com").
          with(body: "def")).to have_been_made
        }.to fail_with(%r(The request POST http://www.example.com/ with body "def" was expected to execute 1 time but it executed 0 times))
      end

      describe "when expected request body is declared as a regexp" do
        it "should satisfy expectation if request was executed with body matching regexp" do
          expect {
            http_request(:post, "http://www.example.com/", body: "abc")
            expect(a_request(:post, "www.example.com").with(body: /^abc$/)).to have_been_made
          }.not_to raise_error
        end

        it "should fail if request was executed with body not matching regexp" do
          expect {
            http_request(:post, "http://www.example.com/", body: "abc")
            expect(a_request(:post, "www.example.com").
            with(body: /^xabc/)).to have_been_made
          }.to fail_with(%r(The request POST http://www.example.com/ with body /\^xabc/ was expected to execute 1 time but it executed 0 times))
        end

      end

      describe "when expected reqest body is declared as a hash" do
        let(:body_hash) { {:a => '1', :b => 'five', 'c' => {'d' => ['e', 'f']}} }
        let(:fail_message) {%r(The request POST http://www.example.com/ with body .+ was expected to execute 1 time but it executed 0 times)}

        describe "when request is made with url encoded body matching hash" do
          it "should satisfy expectation" do
            expect {
              http_request(:post, "http://www.example.com/", body: 'a=1&c[d][]=e&c[d][]=f&b=five')
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.not_to raise_error
          end

          it "should satisfy expectation even if url encoded params have different order" do
            expect {
              http_request(:post, "http://www.example.com/", body: 'a=1&c[d][]=e&b=five&c[d][]=f')
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.not_to raise_error
          end

          it "should fail if request is executed with url encoded body not matching hash" do
            expect {
              http_request(:post, "http://www.example.com/", body: 'c[d][]=f&a=1&c[d][]=e')
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.to fail_with(fail_message)
          end
        end

        describe "when request is executed with json body matching hash and Content-Type is set to json" do
          it "should satisfy expectation" do
            expect {
              http_request(:post, "http://www.example.com/", headers: {'Content-Type' => 'application/json'},
                           body: "{\"a\":\"1\",\"c\":{\"d\":[\"e\",\"f\"]},\"b\":\"five\"}")
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.not_to raise_error
          end

          it "should satisfy expectation even if json body is in different form" do
            expect {
              http_request(:post, "http://www.example.com/", headers: {'Content-Type' => 'application/json'},
                           body: "{\"a\":\"1\",\"b\":\"five\",\"c\":{\"d\":[\"e\",\"f\"]}}")
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.not_to raise_error
          end

          it "should satisfy expectation even if json body contains date string" do
            expect {
              http_request(:post, "http://www.example.com/", headers: {'Content-Type' => 'application/json'},
                           body: "{\"foo\":\"2010-01-01\"}")
              expect(a_request(:post, "www.example.com").with(body: {"foo" => "2010-01-01"})).to have_been_made
            }.not_to raise_error
          end
        end


        describe "when request is executed with xml body matching hash and content type is set to xml" do
          let(:body_hash) { { "opt" => {:a => "1", :b => 'five', 'c' => {'d' => ['e', 'f']}} }}

          it "should satisfy expectation" do
            expect {
              http_request(:post, "http://www.example.com/", headers: {'Content-Type' => 'application/xml'},
                           body: "<opt a=\"1\" b=\"five\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n")
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.not_to raise_error
          end

          it "should satisfy expectation even if xml body is in different form" do
            expect {
              http_request(:post, "http://www.example.com/", headers: {'Content-Type' => 'application/xml'},
                           body: "<opt b=\"five\" a=\"1\">\n  <c>\n    <d>e</d>\n    <d>f</d>\n  </c>\n</opt>\n")
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.not_to raise_error
          end

          it "should satisfy expectation even if xml body contains date string" do
            expect {
              http_request(:post, "http://www.example.com/", headers: {'Content-Type' => 'application/xml'},
                           body: "<opt foo=\"2010-01-01\">\n</opt>\n")
              expect(a_request(:post, "www.example.com").with(body: {"opt" => {"foo" => "2010-01-01"}})).to have_been_made
            }.not_to raise_error
          end
        end
      end

      describe "when expected reqest body is declared as a partial hash matcher" do
        let(:body_hash) { hash_including({:a => '1', 'c' => {'d' => ['e', 'f']}}) }
        let(:fail_message) {%r(The request POST http://www.example.com/ with body hash_including(.+) was expected to execute 1 time but it executed 0 times)}

        describe "when request is made with url encoded body matching hash" do
          it "should satisfy expectation" do
            expect {
              http_request(:post, "http://www.example.com/", body: 'a=1&c[d][]=e&c[d][]=f&b=five')
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.not_to raise_error
          end

          it "should fail if request is executed with url encoded body not matching hash" do
            expect {
              http_request(:post, "http://www.example.com/", body: 'c[d][]=f&a=1&c[d][]=e')
              expect(a_request(:post, "www.example.com").with(body: body_hash)).to have_been_made
            }.to fail_with(fail_message)
          end
        end
      end

      describe "when request with headers is expected" do
        it "should satisfy expectation if request was executed with the same headers" do
          expect {
            http_request(:get, "http://www.example.com/", headers: SAMPLE_HEADERS)
            expect(a_request(:get, "www.example.com").
            with(headers: SAMPLE_HEADERS)).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if request was executed with the same headers but with header value declared as array" do
          expect {
            http_request(:get, "http://www.example.com/", headers: {"a" => "b"})
            expect(a_request(:get, "www.example.com").
            with(headers: {"a" => ["b"]})).to have_been_made
          }.not_to raise_error
        end

        describe "when multiple headers with the same key are passed" do
          it "should satisfy expectation" do
            expect {
              http_request(:get, "http://www.example.com/", headers: {"a" => ["b", "c"]})
              expect(a_request(:get, "www.example.com").
              with(headers: {"a" => ["b", "c"]})).to have_been_made
            }.not_to raise_error
          end

          it "should satisfy expectation even if request was executed with the same headers but different order" do
            expect {
              http_request(:get, "http://www.example.com/", headers: {"a" => ["b", "c"]})
              expect(a_request(:get, "www.example.com").
              with(headers: {"a" => ["c", "b"]})).to have_been_made
            }.not_to raise_error
          end

          it "should fail if request was executed with different headers" do
            expect {
              http_request(:get, "http://www.example.com/", headers: {"a" => ["b", "c"]})
              expect(a_request(:get, "www.example.com").
              with(headers: {"a" => ["b", "d"]})).to have_been_made
            }.to fail_with(%r(The request GET http://www.example.com/ with headers \{'A'=>\['b', 'd'\]\} was expected to execute 1 time but it executed 0 times))
          end
        end

        it "should fail if request was executed with different headers" do
          expect {
            http_request(:get, "http://www.example.com/", headers: SAMPLE_HEADERS)
            expect(a_request(:get, "www.example.com").
            with(headers: { 'Content-Length' => '9999'})).to have_been_made
          }.to fail_with(%r(The request GET http://www.example.com/ with headers \{'Content-Length'=>'9999'\} was expected to execute 1 time but it executed 0 times))
        end

        it "should fail if request was executed with less headers" do
          expect {
            http_request(:get, "http://www.example.com/", headers: {'A' => 'a'})
            expect(a_request(:get, "www.example.com").
            with(headers: {'A' => 'a', 'B' => 'b'})).to have_been_made
          }.to fail_with(%r(The request GET http://www.example.com/ with headers \{'A'=>'a', 'B'=>'b'\} was expected to execute 1 time but it executed 0 times))
        end

        it "should satisfy expectation if request was executed with more headers" do
          expect {
            http_request(:get, "http://www.example.com/",
                         headers: {'A' => 'a', 'B' => 'b'}
                         )
            expect(a_request(:get, "www.example.com").
            with(headers: {'A' => 'a'})).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if request was executed with body and headers but they were not specified in expectantion" do
          expect {
            http_request(:post, "http://www.example.com/",
                         body: "abc",
                         headers: SAMPLE_HEADERS
                         )
            expect(a_request(:post, "www.example.com")).to have_been_made
          }.not_to raise_error
        end

        it "should satisfy expectation if request was executed with headers matching regular expressions" do
          expect {
            http_request(:get, "http://www.example.com/", headers: { 'some-header' => 'MyAppName' })
            expect(a_request(:get, "www.example.com").
            with(headers: { some_header: /^MyAppName$/ })).to have_been_made
          }.not_to raise_error
        end

        it "should fail if request was executed with headers not matching regular expression" do
          expect {
            http_request(:get, "http://www.example.com/", headers: { 'some-header' => 'xMyAppName' })
            expect(a_request(:get, "www.example.com").
            with(headers: { some_header: /^MyAppName$/ })).to have_been_made
          }.to fail_with(%r(The request GET http://www.example.com/ with headers \{'Some-Header'=>/\^MyAppName\$/\} was expected to execute 1 time but it executed 0 times))
        end
      end

      describe "when expectation contains a request matching block" do
        it "should satisfy expectation if request was executed and block evaluated to true" do
          expect {
            http_request(:post, "http://www.example.com/", body: "wadus")
            expect(a_request(:post, "www.example.com").with { |req| req.body == "wadus" }).to have_been_made
          }.not_to raise_error
        end

        it "should fail if request was executed and block evaluated to false" do
          expect {
            http_request(:post, "http://www.example.com/", body: "abc")
            expect(a_request(:post, "www.example.com").with { |req| req.body == "wadus" }).to have_been_made
          }.to fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
        end

        it "should fail if request was not expected but it executed and block matched request" do
          expect {
            http_request(:post, "http://www.example.com/", body: "wadus")
            expect(a_request(:post, "www.example.com").with { |req| req.body == "wadus" }).not_to have_been_made
          }.to fail_with(%r(The request POST http://www.example.com/ with given block was not expected to execute but it executed 1 time))
        end
      end

      describe "with userinfo", unless: (adapter_info.include?(:no_url_auth)) do
        before(:each) do
          stub_request(:any, "http://user:pass@www.example.com")
          stub_request(:any, "http://user:pazz@www.example.com")
        end

        it "should satisfy expectation if request was executed with expected credentials" do
          expect {
            http_request(:get, "http://user:pass@www.example.com/")
            expect(a_request(:get, "http://user:pass@www.example.com")).to have_been_made.once
          }.not_to raise_error
        end

        it "should fail if request was executed with different credentials than expected" do
          expect {
            http_request(:get, "http://user:pass@www.example.com/")
            expect(a_request(:get, "http://user:pazz@www.example.com")).to have_been_made.once
          }.to fail_with(%r(The request GET http://user:pazz@www.example.com/ was expected to execute 1 time but it executed 0 times))
        end

        it "should fail if request was executed without credentials and credentials were expected" do
          expect {
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://user:pass@www.example.com")).to have_been_made.once
          }.to fail_with(%r(The request GET http://user:pass@www.example.com/ was expected to execute 1 time but it executed 0 times))
        end

        it "should fail if request was executed with credentials but expected without credentials" do
          expect {
            http_request(:get, "http://user:pass@www.example.com/")
            expect(a_request(:get, "http://www.example.com")).to have_been_made.once
          }.to fail_with(%r(The request GET http://www.example.com/ was expected to execute 1 time but it executed 0 times))
        end

        it "should fail if request was executed with basic auth header but expected with credentials in userinfo" do
          expect {
            http_request(:get, "http://www.example.com/", basic_auth: ['user', 'pass'])
            expect(a_request(:get, "http://user:pass@www.example.com")).to have_been_made.once
          }.to fail_with(%r(The request GET http://user:pass@www.example.com/ was expected to execute 1 time but it executed 0 times))
        end
      end

      describe "with basic authentication header" do
        before(:each) do
          stub_request(:any, "http://www.example.com").with(basic_auth: ['user', 'pass'])
          stub_request(:any, "http://www.example.com").with(basic_auth: ['user', 'pazz'])
        end

        it "should satisfy expectation if request was executed with expected credentials" do
          expect {
            http_request(:get, "http://www.example.com/", basic_auth: ['user', 'pass'])
            expect(a_request(:get, "http://www.example.com").with(basic_auth: ['user', 'pass'])).to have_been_made.once
          }.not_to raise_error
        end

        it "should satisfy expectation if request was executed with expected credentials passed directly as header" do
          expect {
            http_request(:get, "http://www.example.com/", headers: {'Authorization'=>'Basic dXNlcjpwYXNz'})
            expect(a_request(:get, "http://www.example.com").with(basic_auth: ['user', 'pass'])).to have_been_made.once
          }.not_to raise_error
        end

        it "should fail if request was executed with different credentials than expected" do
          expect {
            http_request(:get, "http://www.example.com/", basic_auth: ['user', 'pass'])
            expect(a_request(:get, "http://www.example.com").with(basic_auth: ['user', 'pazz'])).to have_been_made.once
          }.to fail_with(%r(The request GET http://www.example.com/ with headers {'Authorization'=>'Basic dXNlcjpwYXp6'} was expected to execute 1 time but it executed 0 times))
        end

        it "should fail if request was executed without credentials and credentials were expected" do
          expect {
            http_request(:get, "http://www.example.com/")
            expect(a_request(:get, "http://www.example.com").with(basic_auth: ['user', 'pass'])).to have_been_made.once
          }.to fail_with(%r(The request GET http://www.example.com/ with headers {'Authorization'=>'Basic dXNlcjpwYXNz'} was expected to execute 1 time but it executed 0 times))
        end

        it "should not fail if request was executed with credentials but expected despite credentials" do
          expect {
            http_request(:get, "http://www.example.com/", basic_auth: ['user', 'pass'])
            expect(a_request(:get, "http://www.example.com")).to have_been_made.once
          }.not_to raise_error
        end

        it "should fail if request was executed with basic auth header and credentials were provided in url", unless: (adapter_info.include?(:no_url_auth)) do
          expect {
            stub_request(:any, "http://user:pass@www.example.com")
            http_request(:get, "http://user:pass@www.example.com/")
            expect(a_request(:get, "http://www.example.com").with(basic_auth: ['user', 'pass'])).to have_been_made.once
          }.to fail_with(%r(The request GET http://www.example.com/ with headers {'Authorization'=>'Basic dXNlcjpwYXNz'} was expected to execute 1 time but it executed 0 times))
        end
      end

      describe "when expectations were set on WebMock object" do
        it "should satisfy expectation if expected request was made" do
          expect {
            http_request(:get, "http://www.example.com/")
            expect(WebMock).to have_requested(:get, "http://www.example.com").once
          }.not_to raise_error
        end

        it "should satisfy expectation if request with body and headers was expected and request was made" do
          expect {
            http_request(:post, "http://www.example.com/", body: "abc", headers: {'A' => 'a'})
            expect(WebMock).to have_requested(:post, "http://www.example.com").with(body: "abc", headers: {'A' => 'a'}).once
          }.not_to raise_error
        end

        it "should fail if request expected not to be made was made" do
          expect {
            http_request(:get, "http://www.example.com/")
            expect(WebMock).not_to have_requested(:get, "http://www.example.com")
          }.to fail_with(%r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time))
        end

        it "should satisfy expectation if request was executed and expectation had block which evaluated to true" do
          expect {
            http_request(:post, "http://www.example.com/", body: "wadus")
            expect(WebMock).to have_requested(:post, "www.example.com").with { |req| req.body == "wadus" }
          }.not_to raise_error
        end

        it "should fail if request was executed and expectation had block which evaluated to false" do
          expect {
            http_request(:post, "http://www.example.com/", body: "abc")
            expect(WebMock).to have_requested(:post, "www.example.com").with { |req| req.body == "wadus" }
          }.to fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
        end

        it "should fail if request was expected not to be made but was made and block matched request" do
          expect {
            http_request(:post, "http://www.example.com/", body: "wadus")
            expect(WebMock).not_to have_requested(:post, "www.example.com").with { |req| req.body == "wadus" }
          }.to fail_with(%r(The request POST http://www.example.com/ with given block was not expected to execute but it executed 1 time))
        end
      end

      describe "when expectation is declared using assert_requested" do
        it "should satisfy expectation if requests was made" do
          expect {
            http_request(:get, "http://www.example.com/")
            assert_requested(:get, "http://www.example.com", times: 1)
            assert_requested(:get, "http://www.example.com")
          }.not_to raise_error
        end

        it "should satisfy expectation if request was made with body and headers" do
          expect {
            http_request(:post, "http://www.example.com/", body: "abc", headers: {'A' => 'a'})
            assert_requested(:post, "http://www.example.com", body: "abc", headers: {'A' => 'a'})
          }.not_to raise_error
        end

        it "should fail if request expected not to be made was not wade" do
          expect {
            http_request(:get, "http://www.example.com/")
            assert_not_requested(:get, "http://www.example.com")
          }.to fail_with(%r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time))
        end

        it "should fail if request expected not to be made was made and expectation block evaluated to true" do
          expect {
            http_request(:post, "http://www.example.com/", body: "wadus")
            assert_not_requested(:post, "www.example.com") { |req| req.body == "wadus" }
          }.to fail_with(%r(The request POST http://www.example.com/ with given block was not expected to execute but it executed 1 time))
        end

        it "should satisfy expectation if request was made and expectation block evaluated to true" do
          expect {
            http_request(:post, "http://www.example.com/", body: "wadus")
            assert_requested(:post, "www.example.com") { |req| req.body == "wadus" }
          }.not_to raise_error
        end

        it "should fail if request was made and expectation block evaluated to false" do
          expect {
            http_request(:post, "http://www.example.com/", body: "abc")
            assert_requested(:post, "www.example.com") { |req| req.body == "wadus" }
          }.to fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
        end
      end

      describe "when expectation is declared using assert_requested" do
        it "should satisfy expectation if requests was made" do
          stub_http = stub_http_request(:get, "http://www.example.com")
          expect {
            http_request(:get, "http://www.example.com/")
            assert_requested(stub_http, times: 1)
            assert_requested(stub_http)
          }.not_to raise_error
        end

        it "should fail if request expected not to be made was not wade" do
          stub_http = stub_http_request(:get, "http://www.example.com")
          expect {
            http_request(:get, "http://www.example.com/")
            assert_not_requested(stub_http)
          }.to fail_with(%r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time))
        end
      end
    end


    describe "expectation is set on the request stub" do
      it "should satisfy expectation if expected request was made" do
        stub = stub_request(:get, "http://www.example.com/")
        http_request(:get, "http://www.example.com/")
        expect(stub).to have_been_requested.once
      end

      it "should satisfy expectations if subsequent requests were made" do
        stub = stub_request(:get, "http://www.example.com/")
        http_request(:get, "http://www.example.com/")
        expect(stub).to have_been_requested.once
        http_request(:get, "http://www.example.com/")
        expect(stub).to have_been_requested.twice
      end

      it "should satisfy expectation if expected request with body and headers was made" do
        stub = stub_request(:post, "http://www.example.com").with(body: "abc", headers: {'A' => 'a'})
        http_request(:post, "http://www.example.com/", body: "abc", headers: {'A' => 'a'})
        expect(stub).to have_been_requested.once
      end

      it "should fail if request not expected to be made was made" do
        expect {
          stub = stub_request(:get, "http://www.example.com")
          http_request(:get, "http://www.example.com/")
          expect(stub).not_to have_been_requested
        }.to fail_with(%r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time))
      end

      it "should fail request not expected to be made was made and expectation block evaluated to true" do
        expect {
          stub = stub_request(:post, "www.example.com").with { |req| req.body == "wadus" }
          http_request(:post, "http://www.example.com/", body: "wadus")
          expect(stub).not_to have_been_requested
        }.to fail_with(%r(The request POST http://www.example.com/ with given block was not expected to execute but it executed 1 time))
      end

      it "should satisfy expectation if request was made and expectation block evaluated to true" do
        stub = stub_request(:post, "www.example.com").with { |req| req.body == "wadus" }
        http_request(:post, "http://www.example.com/", body: "wadus")
        expect(stub).to have_been_requested
      end

      it "should satisfy expectation if request was made and expectation block evaluated to false" do
        expect {
          stub_request(:any, /.+/) #stub any request
          stub = stub_request(:post, "www.example.com").with { |req| req.body == "wadus" }
          http_request(:post, "http://www.example.com/", body: "abc")
          expect(stub).to have_been_requested
        }.to fail_with(%r(The request POST http://www.example.com/ with given block was expected to execute 1 time but it executed 0 times))
      end
    end

    describe "when net connect is allowed", net_connect: true do
      before(:each) do
        WebMock.allow_net_connect!
      end

      it "should satisfy expectation if expected requests was made" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).to have_been_made
        }.not_to raise_error
      end

      it "should fail request expected not to be made, was made" do
        expect {
          http_request(:get, "http://www.example.com/")
          expect(a_request(:get, "http://www.example.com")).not_to have_been_made
        }.to fail_with(%r(The request GET http://www.example.com/ was not expected to execute but it executed 1 time))
      end
    end
  end
end
