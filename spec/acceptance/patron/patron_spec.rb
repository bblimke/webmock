require 'spec_helper'
require 'acceptance/webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'acceptance/patron/patron_spec_helper'
  require 'tmpdir'
  require 'fileutils'

  describe "Patron" do
    include PatronSpecHelper

    include_examples "with WebMock"

    describe "when custom functionality is used" do
      before(:each) do
        @sess = Patron::Session.new
        @sess.base_url = "http://www.example.com"
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

        it "should raise same error as Patron if file is not readable for get request" do
          stub_request(:get, "www.example.com")

          allow(File).to receive(:open).and_call_original
          allow(File).to receive(:open).with(@file_path, "w").and_raise(Errno::EACCES)

          expect {
            @sess.get_file("/", @file_path)
          }.to raise_error(ArgumentError, "Unable to open specified file.")

        end

        it "should work with put_file" do
          File.open(@file_path, "w") {|f| f.write "abc"}
          stub_request(:put, "www.example.com").with(body: "abc")
          @sess.put_file("/", @file_path)
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

    describe "proxy matching" do
      before(:each) do
        WebMock.disable_net_connect!
        WebMock.reset!
      end

      it "should match request with correct proxy" do
        stub_request(:get, "www.example.com").with(
          proxy: {"host" => "proxy.example.com", "port" => 8080}
        ).to_return(body: "proxied")

        sess = Patron::Session.new
        sess.base_url = "http://www.example.com"
        sess.proxy = "http://proxy.example.com:8080"
        sess.timeout = 10
        sess.connect_timeout = 10
        response = sess.get("/")
        expect(response.body).to eq("proxied")
      end

      it "should not match request with wrong proxy" do
        stub_request(:get, "www.example.com").with(
          proxy: {"host" => "other-proxy.example.com", "port" => 8080}
        )

        sess = Patron::Session.new
        sess.base_url = "http://www.example.com"
        sess.proxy = "http://proxy.example.com:8080"
        sess.timeout = 10
        sess.connect_timeout = 10
        expect {
          sess.get("/")
        }.to raise_error(WebMock::NetConnectNotAllowedError)
      end

      it "should match request without proxy when proxy pattern is nil" do
        stub_request(:get, "www.example.com").with(proxy: nil).to_return(body: "direct")

        sess = Patron::Session.new
        sess.base_url = "http://www.example.com"
        sess.timeout = 10
        sess.connect_timeout = 10
        response = sess.get("/")
        expect(response.body).to eq("direct")
      end

      it "should match request with proxy when no proxy pattern is specified" do
        stub_request(:get, "www.example.com").to_return(body: "any")

        sess = Patron::Session.new
        sess.base_url = "http://www.example.com"
        sess.proxy = "http://proxy.example.com:8080"
        sess.timeout = 10
        sess.connect_timeout = 10
        response = sess.get("/")
        expect(response.body).to eq("any")
      end
    end
  end
end
