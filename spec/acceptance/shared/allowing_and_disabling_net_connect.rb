shared_context "allowing and disabling net connect" do |*adapter_info|
  describe "when net connect" do
    describe "is allowed", :net_connect => true do
      before(:each) do
        WebMock.allow_net_connect!
      end

      it "should make a real web request if request is not stubbed" do
        expect(http_request(:get, webmock_server_url).status).to eq("200")
      end

      it "should make a real https request if request is not stubbed" do
        unless http_library == :httpclient
          result = http_request(:get, "https://www.google.com/").body
          if result.respond_to? :encode
            result = result.encode(
              'UTF-8',
              'binary',
              :invalid => :replace,
              :undef   => :replace,
              :replace => ''
            )
          end
          expect(result).to match(/.*google.*/)
        end
      end

      it "should return stubbed response if request was stubbed" do
        stub_request(:get, "www.example.com").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/").body).to eq("abc")
      end
    end

    describe "is not allowed" do
      before(:each) do
        WebMock.disable_net_connect!
      end

      it "should return stubbed response if request was stubbed" do
        stub_request(:get, "www.example.com").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/").body).to eq("abc")
      end

      it "should return stubbed response if request with path was stubbed" do
        stub_request(:get, "www.example.com/hello_world").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/hello_world").body).to eq("abc")
      end

      it "should raise exception if request was not stubbed" do
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end
    end

    describe "is not allowed with exception for localhost" do
      before(:each) do
        WebMock.disable_net_connect!(:allow_localhost => true)
      end

      it "should return stubbed response if request was stubbed" do
        stub_request(:get, "www.example.com").to_return(:body => "abc")
        expect(http_request(:get, "http://www.example.com/").body).to eq("abc")
      end

      it "should raise exception if request was not stubbed" do
        expect {
          http_request(:get, "http://www.example.com/")
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com/))
      end

      it "should make a real request to localhost" do
        expect {
          http_request(:get, "http://localhost:12345/")
        }.to raise_error(connection_refused_exception_class)
      end

      it "should make a real request to 127.0.0.1" do
        expect {
          http_request(:get, "http://127.0.0.1:12345/")
        }.to raise_error(connection_refused_exception_class)
      end

      it "should make a real request to 0.0.0.0" do
        expect {
          http_request(:get, "http://0.0.0.0:12345/")
        }.to raise_error(connection_refused_exception_class)
      end
    end

    describe "is not allowed, with exceptions" do
      describe "allowing by host string" do
        before :each do
          WebMock.disable_net_connect!(:allow => 'httpstat.us')
        end

        context "when the host is not allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'disallowed.example.com/foo').to_return(:body => "abc")
            expect(http_request(:get, 'http://disallowed.example.com/foo').body).to eq("abc")
          end

          it "should raise exception if request was not stubbed" do
            expect {
              http_request(:get, 'http://disallowed.example.com/')
            }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://disallowed.example.com))
          end
        end

        context "when the host is allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'httpstat.us/200').to_return(:body => "abc")
            expect(http_request(:get, "http://httpstat.us/200").body).to eq("abc")
          end

          # WARNING: this makes a real HTTP request!
          it "should make a real request to allowed host", :net_connect => true do
            expect(http_request(:get, "http://httpstat.us/200").status).to eq('200')
          end
        end
      end

      describe "allowing by host:port string" do
        def replace_with_different_port(uri)
          uri.sub(%r{:(\d+)}){|m0, m1| ':' + ($~[1].to_i + 1).to_s }
        end

        let(:allowed_host_with_port) { WebMockServer.instance.host_with_port }
        let(:disallowed_host_with_port) { replace_with_different_port(allowed_host_with_port) }

        before :each do
          WebMock.disable_net_connect!(:allow => allowed_host_with_port)
        end

        context "when the host is not allowed" do
          it "should return stubbed response if request was stubbed" do
            request_url = "http://#{disallowed_host_with_port}/foo"
            stub_request(:get, request_url).to_return(:body => "abc")
            expect(http_request(:get, request_url).body).to eq("abc")
          end

          it "should raise exception if request was not stubbed" do
            request_url = "http://#{disallowed_host_with_port}/foo"
            expect {
              http_request(:get, request_url)
            }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET #{request_url}))
          end
        end

        context "when the host is allowed" do
          it "should return stubbed response if request was stubbed" do
            request_url = "http://#{allowed_host_with_port}/foo"
            stub_request(:get, request_url).to_return(:body => "abc")
            expect(http_request(:get, request_url).body).to eq('abc')
          end

          it "should make a real request to allowed host", :net_connect => true do
            request_url = "http://#{allowed_host_with_port}/foo"
            expect(http_request(:get, request_url).status).to eq('200')
          end
        end
      end

      describe "allowing by regular expression" do
        before :each do
          WebMock.disable_net_connect!(:allow => %r{httpstat})
        end

        context "when the host is not allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'disallowed.example.com/foo').to_return(:body => "abc")
            expect(http_request(:get, 'http://disallowed.example.com/foo').body).to eq("abc")
          end

          it "should raise exception if request was not stubbed" do
            expect {
              http_request(:get, 'http://disallowed.example.com/')
            }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://disallowed.example.com))
          end
        end

        context "when the host is allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'httpstat.us/200').to_return(:body => "abc")
            expect(http_request(:get, "http://httpstat.us/200").body).to eq("abc")
          end

          # WARNING: this makes a real HTTP request!
          it "should make a real request to allowed host", :net_connect => true do
            expect(http_request(:get, "http://httpstat.us/200").status).to eq('200')
          end
        end
      end

      describe "allowing by a callable" do
        before :each do
          WebMock.disable_net_connect!(:allow => lambda{|url| url.to_str.include?('httpstat') })
        end

        context "when the host is not allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'disallowed.example.com/foo').to_return(:body => "abc")
            expect(http_request(:get, 'http://disallowed.example.com/foo').body).to eq("abc")
          end

          it "should raise exception if request was not stubbed" do
            expect {
              http_request(:get, 'http://disallowed.example.com/')
            }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://disallowed.example.com))
          end
        end

        context "when the host is allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'httpstat.us/200').to_return(:body => "abc")
            expect(http_request(:get, "http://httpstat.us/200").body).to eq("abc")
          end

          # WARNING: this makes a real HTTP request!
          it "should make a real request to allowed host", :net_connect => true do
            expect(http_request(:get, "http://httpstat.us/200").status).to eq('200')
          end
        end
      end

      describe "allowing by a list of the above" do
        before :each do
          WebMock.disable_net_connect!(:allow => [lambda{|_| false }, %r{foobar}, 'httpstat.us'])
        end

        context "when the host is not allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'disallowed.example.com/foo').to_return(:body => "abc")
            expect(http_request(:get, 'http://disallowed.example.com/foo').body).to eq("abc")
          end

          it "should raise exception if request was not stubbed" do
            expect {
              http_request(:get, 'http://disallowed.example.com/')
            }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://disallowed.example.com))
          end
        end

        context "when the host is allowed" do
          it "should return stubbed response if request was stubbed" do
            stub_request(:get, 'httpstat.us/200').to_return(:body => "abc")
            expect(http_request(:get, "http://httpstat.us/200").body).to eq("abc")
          end

          # WARNING: this makes a real HTTP request!
          it "should make a real request to allowed host", :net_connect => true do
            expect(http_request(:get, "http://httpstat.us/200").status).to eq('200')
          end
        end
      end

    end
  end
end
