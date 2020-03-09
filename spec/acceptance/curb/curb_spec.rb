require 'spec_helper'
require 'acceptance/webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'acceptance/curb/curb_spec_helper'

  shared_examples_for "Curb" do
    include CurbSpecHelper

    include_examples "with WebMock"

    describe "when doing PUTs" do
      it "should stub them" do
        stub_request(:put, "www.example.com").with(body: "01234")
        expect(http_request(:put, "http://www.example.com", body: "01234").
          status).to eq("200")
      end
    end
  end

  describe "Curb features" do
    before(:each) do
      WebMock.disable_net_connect!
      WebMock.reset!
    end

    describe "callbacks" do
      before(:each) do
        @curl = Curl::Easy.new
        @curl.url = "http://example.com"
      end

      describe 'on_debug' do
        it "should call on_debug" do
          stub_request(:any, "example.com").
            to_return(status: 200, headers: { 'Server' => 'nginx' }, body: { hello: :world }.to_json)

          test = []

          @curl.on_debug do |message, operation|
            test << "#{operation} -> #{message}"
          end
          @curl.headers['Content-Type'] = 'application/json'
          @curl.http_post({ hello: :world }.to_json)

          expect(test).to_not be_empty
        end
      end

      it "should call on_success with 2xx response" do
        body = "on_success fired"
        stub_request(:any, "example.com").to_return(body: body)

        test = nil
        @curl.on_success do |c|
          test = c.body_str
        end
        @curl.http_get
        expect(test).to eq(body)
      end

      it "should call on_missing with 4xx response" do
        response_code = 403
        stub_request(:any, "example.com").
          to_return(status: [response_code, "None shall pass"])

        test = nil
        @curl.on_missing do |c, code|
          test = code
        end
        @curl.http_get
        expect(test).to eq(response_code)
      end

      it "should call on_failure with 5xx response" do
        response_code = 599
        stub_request(:any, "example.com").
          to_return(status: [response_code, "Server On Fire"])

        test = nil
        @curl.on_failure do |c, code|
          test = code
        end
        @curl.http_get
        expect(test).to eq(response_code)
      end

      it "should call on_body when response body is read" do
        body = "on_body fired"
        stub_request(:any, "example.com").
          to_return(body: body)

        test = nil
        @curl.on_body do |data|
          test = data
        end
        @curl.http_get
        expect(test).to eq(body)
      end

      it "should call on_body for each chunk with chunked response" do
        stub_request(:any, "example.com").
          to_return(body: ["first_chunk", "second_chunk"],
                    headers: {"Transfer-Encoding" => "chunked"})

        test = []
        @curl.on_body do |data|
          test << data
        end
        @curl.http_get
        expect(test).to eq(["first_chunk", "second_chunk"])
      end

      it "should call on_header when response headers are read" do
        stub_request(:any, "example.com").
          to_return(headers: {one: 1})

        test = []
        @curl.on_header do |data|
          test << data
        end
        @curl.http_get
        expect(test).to eq([
          "HTTP/1.1 200 \r\n",
          'One: 1'
        ])
      end

      it "should call on_complete when request is complete" do
        body = "on_complete fired"
        stub_request(:any, "example.com").to_return(body: body)

        test = nil
        @curl.on_complete do |curl|
          test = curl.body_str
        end
        @curl.http_get
        expect(test).to eq(body)
      end

      it "should call on_progress when portion of response body is read" do
        stub_request(:any, "example.com").to_return(body: "01234")

        test = nil
        @curl.on_progress do |*args|
          expect(args.length).to eq(4)
          args.each {|arg| expect(arg.is_a?(Float)).to eq(true) }
          test = true
        end
        @curl.http_get
        expect(test).to eq(true)
      end

      it "should call callbacks in correct order on successful request" do
        stub_request(:any, "example.com")
        order = []
        @curl.on_success {|*args| order << :on_success }
        @curl.on_missing {|*args| order << :on_missing }
        @curl.on_failure {|*args| order << :on_failure }
        @curl.on_header {|*args| order << :on_header }
        @curl.on_body {|*args| order << :on_body }
        @curl.on_complete {|*args| order << :on_complete }
        @curl.on_progress {|*args| order << :on_progress }
        @curl.http_get

        expect(order).to eq([:on_progress,:on_header,:on_body,:on_complete,:on_success])
      end

      it "should call callbacks in correct order on failed request" do
        stub_request(:any, "example.com").to_return(status: [500, ""])
        order = []
        @curl.on_success {|*args| order << :on_success }
        @curl.on_missing {|*args| order << :on_missing }
        @curl.on_failure {|*args| order << :on_failure }
        @curl.on_header {|*args| order << :on_header }
        @curl.on_body {|*args| order << :on_body }
        @curl.on_complete {|*args| order << :on_complete }
        @curl.on_progress {|*args| order << :on_progress }
        @curl.http_get

        expect(order).to eq([:on_progress,:on_header,:on_body,:on_complete,:on_failure])
      end

      it "should call callbacks in correct order on missing request" do
        stub_request(:any, "example.com").to_return(status: [403, ""])
        order = []
        @curl.on_success {|*args| order << :on_success }
        @curl.on_missing {|*args| order << :on_missing }
        @curl.on_failure {|*args| order << :on_failure }
        @curl.on_header {|*args| order << :on_header }
        @curl.on_body {|*args| order << :on_body }
        @curl.on_complete {|*args| order << :on_complete }
        @curl.on_progress {|*args| order << :on_progress }
        @curl.http_get

        expect(order).to eq([:on_progress,:on_header,:on_body,:on_complete,:on_missing])
      end
    end

    describe '#last_effective_url' do
      before(:each) do
        @curl = Curl::Easy.new
        @curl.url = "http://example.com"
      end

      context 'when not following redirects' do
        before { @curl.follow_location = false }

        it 'should be the same as #url even with a location header' do
          stub_request(:any, 'example.com').
            to_return(body: "abc",
                      status: 302,
                      headers: { 'Location' => 'http://www.example.com' })

          @curl.http_get
          expect(@curl.last_effective_url).to eq('http://example.com')
        end
      end

      context 'when following redirects' do
        before { @curl.follow_location = true }

        it 'should be the same as #url when no location header is present' do
          stub_request(:any, "example.com")
          @curl.http_get
          expect(@curl.last_effective_url).to eq('http://example.com')
        end

        it 'should be the value of the location header when present' do
          stub_request(:any, 'example.com').
            to_return(headers: { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com')

          @curl.http_get
          expect(@curl.last_effective_url).to eq('http://www.example.com')
        end

        it 'should work with more than one redirect' do
          stub_request(:any, 'example.com').
            to_return(headers: { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com').
            to_return(headers: { 'Location' => 'http://blog.example.com' })
          stub_request(:any, 'blog.example.com')

          @curl.http_get
          expect(@curl.last_effective_url).to eq('http://blog.example.com')
        end

        it 'should maintain the original url' do
          stub_request(:any, 'example.com').
            to_return(headers: { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com')

          @curl.http_get
          expect(@curl.url).to eq('http://example.com')
        end

        it 'should have the redirected-to attrs (body, response code)' do
          stub_request(:any, 'example.com').
            to_return(body: 'request A',
                      status: 302,
                      headers: { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com').to_return(body: 'request B')

          @curl.http_get
          expect(@curl.body_str).to eq('request B')
          expect(@curl.response_code).to eq(200)
        end

        it 'should follow more than one redirect' do
          stub_request(:any, 'example.com').
            to_return(headers: { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com').
            to_return(headers: { 'Location' => 'http://blog.example.com' })
          stub_request(:any, 'blog.example.com').to_return(body: 'blog post')

          @curl.http_get
          expect(@curl.url).to eq('http://example.com')
          expect(@curl.body_str).to eq('blog post')
        end
      end
    end

    describe "#content_type" do
      before(:each) do
        @curl = Curl::Easy.new
        @curl.url = "http://example.com"
      end

      context "when response includes Content-Type header" do
        it "returns correct content_type" do
          content_type = "application/json"

          stub_request(:any, 'example.com').
            to_return(body: "abc",
                      status: 200,
                      headers: { 'Content-Type' => content_type })

          @curl.http_get
          expect(@curl.content_type).to eq(content_type)
        end
      end

      context "when response does not include Content-Type header" do
        it "returns nil for content_type" do

          stub_request(:any, 'example.com').
            to_return(body: "abc",
                      status: 200 )

          @curl.http_get
          expect(@curl.content_type).to be_nil
        end
      end
    end

    describe "#chunked_response?" do
      before(:each) do
        @curl = Curl::Easy.new
        @curl.url = "http://example.com"
      end

      it "is true when Transfer-Encoding is 'chunked' and body responds to each" do
        stub_request(:any, 'example.com').
          to_return(body: ["abc", "def"],
                    status: 200,
                    headers: { 'Transfer-Encoding' => 'chunked' })

        @curl.http_get
        expect(@curl).to be_chunked_response
      end

      it "is false when Transfer-Encoding is not 'chunked'" do
        stub_request(:any, 'example.com').
          to_return(body: ["abc", "def"],
                    status: 200)

        @curl.http_get
        expect(@curl).not_to be_chunked_response
      end

      it "is false when Transfer-Encoding is 'chunked' but body does not respond to each" do
        stub_request(:any, 'example.com').
          to_return(body: "abc",
                    status: 200)

        @curl.http_get
        expect(@curl).not_to be_chunked_response
      end
    end
  end

  describe "Webmock with Curb" do
    describe "using #http for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::DynamicHttp

      it "should work with uppercase arguments" do
        stub_request(:get, "www.example.com").to_return(body: "abc")

        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.http(:GET)
        expect(c.body_str).to eq("abc")
      end

      it "should alias body to body_str" do
        stub_request(:get, "www.example.com").to_return(body: "abc")

        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.http(:GET)
        expect(c.body).to eq("abc")
      end

      it "supports array headers passed to Curl::Easy" do
        stub_request(:get, "www.example.com").with(headers: {'X-One' => '1'}).to_return(body: "abc")

        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.headers = ["X-One: 1"]
        c.http(:GET)
        expect(c.body).to eq("abc")
      end

      describe 'match request body' do
        it 'for post' do
          stub_request(:post, "www.example.com").with(body: 'foo=nhe').to_return(body: "abc")

          response = Curl.post("http://www.example.com", {foo: :nhe})
          expect(response.body_str).to eq("abc")
        end

        it 'for patch' do
          stub_request(:patch, "www.example.com").with(body: 'foo=nhe').to_return(body: "abc")

          response = Curl.patch("http://www.example.com", {foo: :nhe})
          expect(response.body_str).to eq("abc")
        end

        it 'for put' do
          stub_request(:put, "www.example.com").with(body: 'foo=nhe').to_return(body: "abc")

          response = Curl.put("http://www.example.com", {foo: :nhe})
          expect(response.body_str).to eq("abc")
        end
      end
    end

    describe "using #http_* methods for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::NamedHttp

      it "should reset @webmock_method after each call" do
        stub_request(:post, "www.example.com").with(body: "01234")
        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.post_body = "01234"
        c.http_post
        expect {
          c.perform
        }.to raise_error(WebMock::NetConnectNotAllowedError, %r(Real HTTP connections are disabled. Unregistered request: GET http://www.example.com))
      end

      it "should work with blank arguments for post" do
        stub_request(:post, "www.example.com").with(body: "01234")
        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.post_body = "01234"
        c.http_post
        expect(c.response_code).to eq(200)
      end

      it "should work with several body arguments for post using the class method" do
        stub_request(:post, "www.example.com").with(body: {user: {first_name: 'Bartosz', last_name: 'Blimke'}})
        c = Curl::Easy.http_post "http://www.example.com", 'user[first_name]=Bartosz', 'user[last_name]=Blimke'
        expect(c.response_code).to eq(200)
      end

      it "should work with blank arguments for put" do
        stub_request(:put, "www.example.com").with(body: "01234")
        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.put_data = "01234"
        c.http_put
        expect(c.response_code).to eq(200)
      end

      it "should work with multiple arguments for post" do
        data = { name: "john", address: "111 example ave" }

        stub_request(:post, "www.example.com").with(body: data)
        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.http_post Curl::PostField.content('name', data[:name]),  Curl::PostField.content('address', data[:address])

        expect(c.response_code).to eq(200)
      end

    end

    describe "using #perform for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::Perform
    end

    describe "using .http_* methods for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::ClassNamedHttp
    end

    describe "using .perform for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::ClassPerform
    end

    describe "using #reset" do
      before do
        @curl = Curl::Easy.new
        @curl.url = "http://example.com"
        stub_request(:any, "example.com").
          to_return(body: "abc",
                    headers: { "Content-Type" => "application/json" })
        @curl.http_get
      end

      it "should clear all memoized response fields" do
        @curl.reset
        expect(@curl).to have_attributes(
          body_str: nil,
          content_type: nil,
          header_str: nil,
          last_effective_url: nil,
          response_code: 0,
        )
      end
    end
  end
end
