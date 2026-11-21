require 'spec_helper'
require 'acceptance/webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'acceptance/patron/patron_spec_helper'
  require 'tmpdir'
  require 'fileutils'
  require 'socket'

  describe "Patron" do
    include PatronSpecHelper

    include_examples "with WebMock"

    describe "when custom functionality is used" do
      before(:each) do
        @sess = Patron::Session.new
        @sess.base_url = "http://www.example.com"
      end

      after(:each) do
        WebMock.disable_net_connect!
        WebMock.reset_callbacks
      end

      let(:real_statuses) { [] }

      # Allows real requests and records the status of each one
      def real_session
        WebMock.allow_net_connect!
        WebMock.after_request(real_requests_only: true) { |_, response| real_statuses << response.status }
        Patron::Session.new.tap { |sess| sess.base_url = "http://#{WebMockServer.instance.host_with_port}/" }
      end

      it "should allow stubbing PATCH request with body" do
        stub_request(:patch, "http://www.example.com/")
          .with(body: "abc")

        @sess.patch('/', "abc")
      end

      describe "file requests" do

        before(:each) do
          @dir_path = Dir.mktmpdir('webmock-')
          @file_path = File.join(@dir_path, "webmock_temp_test_file")
          FileUtils.rm_rf(@file_path) if File.exist?(@file_path)
        end

        after(:each) do
          FileUtils.rm_rf(@dir_path) if File.exist?(@dir_path)
        end

        it "should work with get_file" do
          stub_request(:get, "www.example.com").to_return(body: "abc")
          @sess.get_file("/", @file_path)
          expect(File.read(@file_path)).to eq("abc")
        end

        it "should raise NetConnectNotAllowedError for an unstubbed get_file" do
          expect {
            @sess.get_file("/", @file_path)
          }.to raise_error(WebMock::NetConnectNotAllowedError)
        end

        it "should make a real get_file request when net connect is allowed" do
          sess = real_session
          sess.get_file("/", @file_path)
          expect(File.read(@file_path)).to eq("hello world")
          expect(real_statuses).to eq([[200, "OK"]])
          expect(a_request(:get, sess.base_url)).to have_been_made.once
        end

        if Patron::Session.public_method_defined?(:stream)
          it "should raise same error as Patron if file is not writable for get request" do
            stub_request(:get, "www.example.com")

            allow(File).to receive(:open).and_call_original
            allow(File).to receive(:open).with(@file_path, "wb").and_raise(Errno::EACCES)

            expect {
              @sess.get_file("/", @file_path)
            }.to raise_error(Errno::EACCES)
          end

          it "should match the stub for get_file" do
            stub_request(:get, "www.example.com").to_return(status: [201, "Created"], body: "abc")
            response = @sess.get_file("/", @file_path)
            expect(response.status).to eq(201)
            expect(a_request(:get, "www.example.com")).to have_been_made.once
          end

          it "should return a response without a body for get_file, as Patron does" do
            stub_request(:get, "www.example.com").to_return(body: "abc")
            response = @sess.get_file("/", @file_path)
            expect(response.body).to be_nil
            expect(File.read(@file_path)).to eq("abc")
          end

          it "should match the stub for a GET request with the file option" do
            stub_request(:get, "www.example.com").to_return(body: "abc")
            @sess.request(:get, "/", {}, file: @file_path)
            expect(File.read(@file_path)).to eq("abc")
          end
        else
          it "should raise same error as Patron if file is not readable for get request" do
            stub_request(:get, "www.example.com")

            allow(File).to receive(:open).and_call_original
            allow(File).to receive(:open).with(@file_path, "w").and_raise(Errno::EACCES)

            expect {
              @sess.get_file("/", @file_path)
            }.to raise_error(ArgumentError, "Unable to open specified file.")

          end
        end

        it "records the whole file when the request body has a path" do
          contents = "abc\xFF".b
          File.binwrite(@file_path, contents)
          stub_request(:post, "www.example.com").with(body: contents)
          File.open(@file_path, "rb") do |file|
            file.read(1)
            @sess.post("/", file)
            expect(file.pos).to eq(1)
          end
          expect(executed_requests.last.body).to eq(contents)
        end

        it "should work with put_file" do
          File.open(@file_path, "w") {|f| f.write "abc"}
          stub_request(:put, "www.example.com").with(body: "abc")
          @sess.put_file("/", @file_path)
        end

        it "matches a post_file stub against the text read from the file" do
          File.write(@file_path, "café")
          contents = File.read(@file_path)
          stub_request(:post, "www.example.com").with(body: contents)
          @sess.post_file("/", @file_path)
          expect(executed_requests.last.body.encoding).to eq(contents.encoding)
        end

        it "should work with post_file" do
          File.open(@file_path, "w") {|f| f.write "abc"}
          stub_request(:post, "www.example.com").with(body: "abc")
          @sess.post_file("/", @file_path)
        end

        it "should raise same error as Patron if file is not readable for post request" do
          stub_request(:post, "www.example.com").with(body: "abc")
          expect {
            @sess.post_file("/", "/path/to/non/existing/file")
          }.to raise_error(ArgumentError, "Unable to open specified file.")
        end

      end

      if Patron::Session.public_method_defined?(:stream)
        describe "streamed requests" do
          it "should yield the stubbed head and body" do
            stub_request(:get, "www.example.com/stream").
              to_return(status: [201, "Created"], headers: {"Content-Type" => "text/plain"}, body: "abcdef")

            chunks = []
            stats = @sess.get_stream("/stream") do |stream|
              expect(stream.status).to eq(201)
              expect(stream.status_line).to eq("HTTP/1.1 201 Created")
              expect(stream.headers["Content-Type"]).to eq("text/plain")
              expect(stream.content_type).to eq("text/plain")
              chunks << stream.readpartial(4)
              chunks << stream.read
              expect(stream.eof?).to be(true)
            end

            expect(chunks).to eq(["abcd", "ef"])
            expect(stats).to be_a(Patron::TransferStats)
            expect(stats.status).to eq(201)
            expect(stats.headers["Content-Type"]).to eq("text/plain")
            expect(stats.downloaded_bytes).to eq(6)
            expect(stats.complete?).to be(true)
          end

          it "should yield the stubbed body in chunks and lines" do
            stub_request(:get, "www.example.com").to_return(body: "a\nb\nc")
            chunks = []
            lines = []
            @sess.get_stream("/") { |stream| stream.each { |chunk| chunks << chunk } }
            @sess.get_stream("/") { |stream| stream.each_line { |line| lines << line } }
            expect(chunks).to eq(["a\nb\nc"])
            expect(lines).to eq(["a\n", "b\n", "c"])
          end

          it "should report a stubbed body left unread as incomplete" do
            stub_request(:get, "www.example.com").to_return(body: "abcdef")
            stats = @sess.get_stream("/") { |stream| stream.read(2) }
            expect(stats.downloaded_bytes).to eq(2)
            expect(stats.complete?).to be(false)
          end

          it "should report a drained body as complete" do
            stub_request(:get, "www.example.com").to_return(body: "abcdef")
            drained = nil
            stats = @sess.get_stream("/") { |stream| drained = stream.drain! }
            expect(drained).to eq(6)
            expect(stats.complete?).to be(true)
          end

          it "should yield a stream with the public methods of Patron::ResponseStream" do
            stub_request(:get, "www.example.com")
            stream_methods = nil
            @sess.get_stream("/") { |stream| stream_methods = stream.public_methods - Object.public_instance_methods }
            expect(stream_methods).to match_array(Patron::ResponseStream.public_instance_methods - Object.public_instance_methods)
          end

          it "should close the stream when the block ends" do
            stub_request(:get, "www.example.com").to_return(body: "abc")
            stream = nil
            @sess.get_stream("/") { |s| stream = s }
            expect(stream.closed?).to be(true)
            expect { stream.read }.to raise_error(IOError)
          end

          it "should match the request body of post_stream" do
            stub_request(:post, "www.example.com").with(body: "abc").to_return(body: "def")
            body = nil
            stats = @sess.post_stream("/", "abc") { |stream| body = stream.read }
            expect(body).to eq("def")
            expect(stats.uploaded_bytes).to eq(3)
          end

          it "should raise Patron::TimeoutError for a stubbed timeout" do
            stub_request(:get, "www.example.com").to_timeout
            expect {
              @sess.get_stream("/") { |stream| stream.read }
            }.to raise_error(Patron::TimeoutError)
          end

          it "should raise the stubbed exception" do
            stub_request(:get, "www.example.com").to_raise(Patron::ConnectionFailed)
            expect {
              @sess.get_stream("/") { |stream| stream.read }
            }.to raise_error(Patron::ConnectionFailed)
          end

          it "should raise NetConnectNotAllowedError for an unstubbed request" do
            expect {
              @sess.get_stream("/") { |stream| stream.read }
            }.to raise_error(WebMock::NetConnectNotAllowedError)
          end

          it "should match the headers and query of a streamed request" do
            stub_request(:get, "www.example.com/events").
              with(query: {"a" => "1"}, headers: {"Accept" => "text/event-stream"}).
              to_return(body: "data: x\n\n")
            body = nil
            @sess.get_stream("/events", {"Accept" => "text/event-stream"}, query: {a: 1}) { |stream| body = stream.read }
            expect(body).to eq("data: x\n\n")
          end

          it "should invoke after_request callbacks with the stubbed response" do
            stub_request(:get, "www.example.com").to_return(body: "abc")
            responses = []
            WebMock.after_request { |_, response| responses << response }
            @sess.get_stream("/") { |stream| stream.read }
            expect(responses.map(&:body)).to eq(["abc"])
          end

          it "should close the stream and invoke callbacks when the block breaks" do
            stub_request(:get, "www.example.com").to_return(body: "abc")
            callbacks = 0
            WebMock.after_request { callbacks += 1 }
            stream = nil
            @sess.get_stream("/") do |s|
              stream = s
              break
            end
            expect(stream.closed?).to be(true)
            expect(callbacks).to eq(1)
            expect(a_request(:get, "www.example.com")).to have_been_made.once
          end

          it "should close the stream and invoke callbacks when the block raises" do
            stub_request(:get, "www.example.com").to_return(body: "abc")
            callbacks = 0
            WebMock.after_request { callbacks += 1 }
            stream = nil
            expect {
              @sess.get_stream("/") do |s|
                stream = s
                raise ArgumentError, "boom"
              end
            }.to raise_error(ArgumentError, "boom")
            expect(stream.closed?).to be(true)
            expect(callbacks).to eq(1)
          end

          it "should make a real request when net connect is allowed" do
            body = nil
            stats = real_session.get_stream("/") { |stream| body = stream.read }
            expect(body).to eq("hello world")
            expect(stats.complete?).to be(true)
            expect(real_statuses).to eq([[200, "OK"]])
          end

          it "should invoke callbacks for a real request when the block breaks" do
            real_session.get_stream("/") { break }
            expect(real_statuses).to eq([[200, "OK"]])
          end
        end
      end

      describe "real requests with credentials" do
        # Serves one request and returns the head that the session sent
        def request_head_sent_by
          server = TCPServer.new("127.0.0.1", 0)
          thread = Thread.new do
            client = server.accept
            lines = []
            while (line = client.gets) && line != "\r\n"
              lines << line
            end
            client.write("HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok")
            client.close
            lines.join
          end
          thread.report_on_exception = false

          WebMock.allow_net_connect!
          sess = Patron::Session.new
          sess.base_url = "http://127.0.0.1:#{server.addr[1]}"
          sess.username = "user"
          sess.password = "pass"
          sess.auth_type = :digest
          yield sess
          thread.value
        ensure
          server.close if server
        end

        it "should not add a Basic Authorization header to the request" do
          head = request_head_sent_by { |sess| sess.get("/") }
          expect(head).not_to match(/^Authorization:/i)
        end

        if Patron::Session.public_method_defined?(:stream)
          it "should not add a Basic Authorization header to a get_file request" do
            Dir.mktmpdir("webmock-") do |dir|
              head = request_head_sent_by { |sess| sess.get_file("/", File.join(dir, "file")) }
              expect(head).not_to match(/^Authorization:/i)
            end
          end
        end
      end

      describe "handling errors same way as patron" do
        it "should raise error if put request has neither upload_data nor file_name" do
          stub_request(:post, "www.example.com")
          expect {
            @sess.post("/", nil)
          }.to raise_error(ArgumentError, "Must provide either data or a filename when doing a PUT or POST")
        end
      end

      it "should work with WebDAV copy request" do
        stub_request(:copy, "www.example.com/abc").with(headers: {'Destination' => "/def"})
        @sess.copy("/abc", "/def")
      end

      describe "handling encoding same way as patron" do
        around(:each) do |example|
          @encoding = Encoding.default_internal
          Encoding.default_internal = "UTF-8"
          example.run
          Encoding.default_internal = @encoding
        end

        it "should not encode body with default encoding" do
          stub_request(:get, "www.example.com").
            to_return(body: "Øl")

          expect(@sess.get("").body.encoding).to eq(Encoding::ASCII_8BIT)
          expect(@sess.get("").inspectable_body.encoding).to eq(Encoding::UTF_8)
        end

        it "should not encode body to default internal" do
          stub_request(:get, "www.example.com").
            to_return(headers: {'Content-Type' => 'text/html; charset=iso-8859-1'},
                      body: "Øl".encode("iso-8859-1"))

          expect(@sess.get("").body.encoding).to eq(Encoding::ASCII_8BIT)
          expect(@sess.get("").decoded_body.encoding).to eq(Encoding.default_internal)
        end
      end
    end
  end
end
