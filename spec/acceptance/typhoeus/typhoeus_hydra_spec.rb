require 'spec_helper'
require 'acceptance/webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'acceptance/typhoeus/typhoeus_hydra_spec_helper'

  describe "Typhoeus::Hydra" do
    include TyphoeusHydraSpecHelper
    let(:hydra) { Typhoeus::Hydra.new }

    before do
      Typhoeus::Expectation.clear
    end

    include_context "with WebMock"

    describe "Typhoeus::Hydra features" do
      before(:each) do
        WebMock.disable_net_connect!
        WebMock.reset!
      end

      it "isolates nested array bodies from the caller and from history readers" do
        url = "http://example.com/"
        stub_request(:post, url)
        payload = [{"field" => [+"before"]}]
        Typhoeus.post(url, body: payload)
        executed_requests.last.body.first["field"].first.replace("edited")
        expect(payload.first["field"]).to eq(["before"])
        payload.first["field"].first.replace("later")
        expect(executed_requests.last.body).to eq([{"field" => ["before"]}])
      end

      it "records file parts inside an array by path and counts repeated uploads" do
        url = "http://example.com/"
        File.open(__FILE__, "rb") do |file|
          stub = stub_request(:post, url).with { |req| req.body.first["file"].equal?(file) }
          2.times { Typhoeus.post(url, body: [{"file" => file}]) }
          expect(stub).to have_been_requested.twice
        end
        stub_request(:post, url)
        Typhoeus.post(url, body: [{"file" => __FILE__}])
        path = Pathname.new(__FILE__)
        expect(executed_requests.map { |req| req.body.first["file"] }).to eq([path, path, __FILE__])
        expect(a_request(:post, url).with { |req| req.body.first["file"] == path }).to have_been_made.twice
      end

      describe "supposed response fields" do
        it "present" do
          stub_request(:get, "http://www.example.com").to_return(headers: {'X-Test' => '1'})
          response = Typhoeus.get("http://www.example.com")
          expect(response.code).not_to be_nil
          expect(response.status_message).not_to be_nil
          expect(response.body).not_to be_nil
          expect(response.headers).not_to be_nil
          expect(response.effective_url).not_to be_nil
          expect(response.total_time).to eq 0.0
          expect(response.time).to eq 0.0  # aliased by Typhoeus::Response::Informations
          expect(response.starttransfer_time).to eq 0.0
          expect(response.start_transfer_time).to eq 0.0  # aliased by Typhoeus::Response::Informations
          expect(response.appconnect_time).to eq 0.0
          expect(response.pretransfer_time).to eq 0.0
          expect(response.connect_time).to eq 0.0
          expect(response.namelookup_time).to eq 0.0
          expect(response.redirect_time).to eq 0.0
        end
      end

      describe 'effective_url' do
        context 'original request url is provided with custom port' do
          it "returns effective_url as string with custom port" do
            stub_request(:get, "http://www.example.com:8080").to_return(headers: {'X-Test' => '1'})
            response = Typhoeus.get("http://www.example.com:8080")
            expect(response.effective_url).to eq 'http://www.example.com:8080/'
          end
        end

        context 'original request url is provided with standard port' do
          it "returns effective_url as string with the port, as curl does" do
            stub_request(:get, "http://www.example.com:80").to_return(headers: {'X-Test' => '1'})
            response = Typhoeus.get("http://www.example.com:80")
            expect(response.effective_url).to eq 'http://www.example.com:80/'
          end
        end

        context 'original request url is provided with no port' do
          it "returns effective_url as string with no port" do
            stub_request(:get, "http://www.example.com").to_return(headers: {'X-Test' => '1'})
            response = Typhoeus.get("http://www.example.com")
            expect(response.effective_url).to eq 'http://www.example.com/'
          end
        end

        context 'original request url has no scheme' do
          it "returns effective_url with http://, as curl does" do
            stub_request(:get, "http://localhost:3000/foo")
            response = Typhoeus.get("localhost:3000/foo")
            expect(response.effective_url).to eq 'http://localhost:3000/foo'
          end
        end

        context 'original request url has a single slash after the scheme' do
          it "returns effective_url with two slashes, as curl does" do
            stub_request(:get, "http://www.example.com/foo")
            response = Typhoeus.get("http:/www.example.com/foo")
            expect(response.effective_url).to eq 'http://www.example.com/foo'
          end
        end

        context 'original request url has dot segments and an empty query' do
          it "returns effective_url without them, as curl does" do
            stub_request(:get, "http://www.example.com/a/c")
            response = Typhoeus.get("http://www.example.com/a/./b/../c?")
            expect(response.effective_url).to eq 'http://www.example.com/a/c'
          end
        end

        context 'original request url has a query' do
          it "returns effective_url with the query in its original order and encoding" do
            stub_request(:get, "http://www.example.com/?b=2&a=%41")
            response = Typhoeus.get("http://www.example.com/?b=2&a=%41")
            expect(response.effective_url).to eq 'http://www.example.com/?b=2&a=%41'
          end

          it "returns effective_url with params given as an option" do
            stub_request(:get, "http://www.example.com/?b=2&a=1")
            response = Typhoeus.get("http://www.example.com", params: {b: 2, a: 1})
            expect(response.effective_url).to eq 'http://www.example.com/?b=2&a=1'
          end
        end
      end

      describe "return_code and response_headers" do
        it "returns :ok and the stubbed status and headers for a completed request" do
          stub_request(:get, "http://www.example.com").to_return(status: [404, "Not Found"], headers: {'X-Test' => '1'})
          response = Typhoeus.get("http://www.example.com")
          expect(response.return_code).to eq :ok
          expect(response.response_headers).to eq "HTTP/1.1 404 Not Found\r\nX-Test: 1\r\n\r\n"
        end

        it "returns \"No error\" and empty headers for a stub without headers" do
          stub_request(:get, "http://www.example.com").to_return(status: [200, "OK"])
          response = Typhoeus.get("http://www.example.com")
          expect(response.return_message).to eq "No error"
          expect(response.response_headers).to eq "HTTP/1.1 200 OK\r\n\r\n"
          expect(response.headers).to eq({})
        end

        it "returns response_headers as bytes, even for values in different encodings" do
          stub_request(:get, "http://www.example.com").to_return(status: [200, "OK"], headers: {'X-A' => "\xC3\xA9".b, 'X-B' => "\u00FC"})
          response = Typhoeus.get("http://www.example.com")
          expect(response.response_headers).to eq "HTTP/1.1 200 OK\r\nX-A: \xC3\xA9\r\nX-B: \xC3\xBC\r\n\r\n".b
        end

        it "puts each value of a repeated header on its own line" do
          stub_request(:get, "http://www.example.com").to_return(status: [200, "OK"], headers: {'Set-Cookie' => ['a=1', 'b=2']})
          response = Typhoeus.get("http://www.example.com")
          expect(response.response_headers).to eq "HTTP/1.1 200 OK\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\n\r\n"
        end

        it "returns :operation_timedout, no response_headers and the effective_url for a timeout" do
          stub_request(:get, "http://www.example.com").to_timeout
          response = Typhoeus.get("http://www.example.com")
          expect(response.return_code).to eq :operation_timedout
          expect(response.response_headers).to eq ""
          expect(response.effective_url).to eq 'http://www.example.com/'
        end
      end

      describe "when params are used" do
        it "should take into account params for POST request" do
          stub_request(:post, "www.example.com/?hello=world").with(query: {hello: 'world'})
          request = Typhoeus::Request.new("http://www.example.com", method: :post, params: {hello: 'world'})
          hydra.queue(request)
          hydra.run
        end

        it "should take into account body for POST request" do
          stub_request(:post, "www.example.com").with(body: {hello: 'world'})
          response = Typhoeus.post("http://www.example.com", method: :post, body: {hello: 'world'})
          expect(response.code).to eq(200)
        end

        it "should take into account params for GET request" do
          stub_request(:get, "http://www.example.com/?hello=world").to_return({})
          request = Typhoeus::Request.new("http://www.example.com/?hello=world", method: :get)
          hydra.queue(request)
          hydra.run
        end
      end

      describe "when the body is a Hash" do
        include LocalHTTPServer

        it "records the form Content-Type, so Integer values and header stubs match" do
          stub_request(:post, "www.example.com").
            with(body: {"a" => {"b" => 1}}, headers: {"Content-Type" => "application/x-www-form-urlencoded"})
          expect(Typhoeus.post("http://www.example.com", body: {a: {b: 1}}).code).to eq(200)
        end

        # content_type counts as Content-Type, since WebMock reads header names
        # that way, although libcurl then sends both headers.
        it "keeps a Content-Type given in the request" do
          stub_request(:post, "www.example.com")
          Typhoeus.post("http://www.example.com", body: {a: 1}, headers: {"Content-Type" => "application/json"})
          Typhoeus.post("http://www.example.com", body: {a: 1}, headers: {content_type: "text/plain"})
          expect(executed_requests.map(&:content_type)).to eq(["application/json", "text/plain"])
        end

        it "records no Content-Type with the nobody option" do
          stub_request(:post, "http://example.com")
          Typhoeus.post("http://example.com", body: {a: 1}, nobody: true)
          expect(executed_requests.last.content_type).to be_nil
        end

        # With Ethon before 0.19, Typhoeus can't build the URL of such a request.
        if Gem::Version.new(Ethon::VERSION) >= Gem::Version.new("0.19")
          it "records no Content-Type for a form Ethon can't read" do
            stub_request(:post, "http://example.com")
            file = Tempfile.new("upload")
            file.unlink
            Typhoeus.post("http://example.com", body: {a: file})
            expect(executed_requests.last.content_type).to be_nil
          ensure
            file&.close!
          end
        end

        it "records the Content-Type that libcurl sends" do
          file = File.open(__FILE__)
          requests = [
            [:post, {a: 1}], [:patch, {a: 1}], [:delete, {a: 1}], [:get, {a: 1}],
            [:put, {a: 1}], [:head, {a: 1}], [:post, {}], [:get, {}],
            [:post, {a: 1}, {multipart: true}], [:post, {a: file}],
            [:post, {a: [file]}], [:post, {}, {multipart: true}],
            # Ethon 0.19 sends no body for a form without values, older
            # versions send an empty one, so this is checked last.
            [:patch, {a: {}}]
          ]
          heads = capture_request_heads(requests.size) do |port|
            requests.each do |method, body, options|
              response = Typhoeus::Request.new("http://127.0.0.1:#{port}/", method: method, body: body, **(options || {})).run
              expect(response.code).to eq(200)
            end
          end
          received = heads.map { |head| head[/^content-type:\s*([^;\r]+)/i, 1] }

          form = "application/x-www-form-urlencoded"
          multipart = "multipart/form-data"
          expect(received[0...-1]).to eq([form, form, form, form, nil, nil, form, nil, multipart, multipart, multipart, form])
          expect(executed_requests.map(&:content_type)).to eq(received.map { |type| type unless type == "multipart/form-data" })
        ensure
          file&.close
        end
      end

      describe "the cookie option" do
        include LocalHTTPServer

        it "is matched as the Cookie header" do
          stub_request(:get, "www.example.com").with(headers: {"Cookie" => "key=value"}).to_return(body: "Cookies Accepted!")
          expect(Typhoeus.get("http://www.example.com", cookie: "key=value").body).to eq("Cookies Accepted!")
        end

        it "records the Cookie header that libcurl sends" do
          requests = [
            {cookie: "key=value"},
            {cookie: "key=value", headers: {"Cookie" => "other=1"}},
            {cookie: "key=value", headers: {"cookie" => "other=1"}},
            {cookie: ""},
            {}
          ]
          heads = capture_request_heads(requests.size) do |port|
            requests.each do |options|
              expect(Typhoeus::Request.new("http://127.0.0.1:#{port}/", **options).run.code).to eq(200)
            end
          end
          received = heads.map { |head| head[/^cookie:[ \t]*([^\r]*)/i, 1] }

          expect(received.first(3)).to eq(["key=value", "other=1", "other=1"])
          expect(executed_requests.map { |request| (request.headers || {})["Cookie"] }).to eq(received)
        end

        it "records no Cookie header when libcurl's cookie engine can add to it" do
          heads = capture_request_heads do |port|
            Typhoeus::Request.new("http://127.0.0.1:#{port}/", cookie: "manual=1",
              cookielist: "Set-Cookie: jar=2; domain=127.0.0.1").run
          end

          expect(heads.first[/^cookie:[ \t]*([^\r]*)/i, 1]).to eq("jar=2; manual=1")
          expect(executed_requests.last.headers.to_h).not_to have_key("Cookie")
        end
      end

      describe "timeouts" do
        it "should support native typhoeus timeouts" do
          stub_request(:any, "example.com").to_timeout

          request = Typhoeus::Request.new("http://example.com", method: :get)
          hydra.queue(request)
          hydra.run

          expect(request.response).to be_timed_out
        end
      end

      describe "callbacks" do
        before(:each) do
          @request = Typhoeus::Request.new("http://example.com")
        end

        it "should call on_complete with 2xx response" do
          body = "on_success fired"
          stub_request(:any, "example.com").to_return(body: body)

          test = nil
          Typhoeus.on_complete do |c|
            test = c.body
          end
          hydra.queue @request
          hydra.run
          expect(test).to eq(body)
        end

        it "should call on_complete with 5xx response" do
          response_code = 599
          stub_request(:any, "example.com").to_return(status: [response_code, "Server On Fire"])

          test = nil
          Typhoeus.on_complete do |c|
            test = c.code
          end
          hydra.queue @request
          hydra.run
          expect(test).to eq(response_code)
        end

        it "should call on_body with 2xx response" do
          body = "on_body fired"
          stub_request(:any, "example.com").to_return(body: body)

          test_body = nil
          test_complete = nil
          skip("This test requires a newer version of Typhoeus") unless @request.respond_to?(:on_body)
          @request.on_body do |body_chunk, response|
            test_body = body_chunk
          end
          @request.on_complete do |response|
            test_complete = response.body
          end
          hydra.queue @request
          hydra.run
          expect(test_body).to eq(body)
          expect(test_complete).to eq("")
        end

        it "should initialize the streaming response body with a mutible (non-frozen) string" do
          skip("This test requires a newer version of Typhoeus") unless @request.respond_to?(:on_body)

          stub_request(:any, "example.com").to_return(body: "body")

          @request.on_body do |body_chunk, response|
            response.body << body_chunk
          end
          hydra.queue @request

          expect{ hydra.run }.not_to raise_error
        end

        it "should call on_headers with 2xx response" do
          body = "on_headers fired"
          stub_request(:any, "example.com").to_return(body: body, headers: {'X-Test' => '1'})

          test_headers = nil
          skip("This test requires a newer version of Typhoeus") unless @request.respond_to?(:on_headers)
          @request.on_headers do |response|
            test_headers = response.headers
          end
          hydra.queue @request
          hydra.run
          expect(test_headers.to_h).to include('X-Test' => '1')
        end
      end
    end
  end
end
