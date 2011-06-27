require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require 'webmock_shared'

unless RUBY_PLATFORM =~ /java/
  require 'curb_spec_helper'

  shared_examples_for "Curb" do
    include CurbSpecHelper

    it_should_behave_like "WebMock"

    describe "when doing PUTs" do
      it "should stub them" do
        stub_http_request(:put, "www.example.com").with(:body => "01234")
        http_request(:put, "http://www.example.com", :body => "01234").
          status.should be == "200"
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

      it "should call on_success with 2xx response" do
        body = "on_success fired"
        stub_request(:any, "example.com").to_return(:body => body)

        test = nil
        @curl.on_success do |c|
          test = c.body_str
        end
        @curl.http_get
        test.should be == body
      end

      it "should call on_failure with 5xx response" do
        response_code = 599
        stub_request(:any, "example.com").
          to_return(:status => [response_code, "Server On Fire"])

        test = nil
        @curl.on_failure do |c, code|
          test = code
        end
        @curl.http_get
        test.should be == response_code
      end

      it "should call on_body when response body is read" do
        body = "on_body fired"
        stub_request(:any, "example.com").
          to_return(:body => body)

        test = nil
        @curl.on_body do |data|
          test = data
        end
        @curl.http_get
        test.should be == body
      end

      it "should call on_header when response headers are read" do
        stub_request(:any, "example.com").
          to_return(:headers => {:one => 1})

        test = nil
        @curl.on_header do |data|
          test = data
        end
        @curl.http_get
        test.should match(/One: 1/)
      end

      it "should call on_complete when request is complete" do
        body = "on_complete fired"
        stub_request(:any, "example.com").to_return(:body => body)

        test = nil
        @curl.on_complete do |curl|
          test = curl.body_str
        end
        @curl.http_get
        test.should be == body
      end

      it "should call on_progress when portion of response body is read" do
        stub_request(:any, "example.com").to_return(:body => "01234")

        test = nil
        @curl.on_progress do |*args|
          args.length.should be == 4
          args.each {|arg| arg.is_a?(Float).should be == true }
          test = true
        end
        @curl.http_get
        test.should be == true
      end

      it "should call callbacks in correct order on successful request" do
        stub_request(:any, "example.com")
        order = []
        @curl.on_success {|*args| order << :on_success }
        @curl.on_failure {|*args| order << :on_failure }
        @curl.on_header {|*args| order << :on_header }
        @curl.on_body {|*args| order << :on_body }
        @curl.on_complete {|*args| order << :on_complete }
        @curl.on_progress {|*args| order << :on_progress }
        @curl.http_get

        order.should be == [:on_progress,:on_header,:on_body,:on_complete,:on_success]
      end

      it "should call callbacks in correct order on successful request" do
        stub_request(:any, "example.com").to_return(:status => [500, ""])
        order = []
        @curl.on_success {|*args| order << :on_success }
        @curl.on_failure {|*args| order << :on_failure }
        @curl.on_header {|*args| order << :on_header }
        @curl.on_body {|*args| order << :on_body }
        @curl.on_complete {|*args| order << :on_complete }
        @curl.on_progress {|*args| order << :on_progress }
        @curl.http_get

        order.should be == [:on_progress,:on_header,:on_body,:on_complete,:on_failure]
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
            to_return(:body    => "abc",
                      :status  => 302,
                      :headers => { 'Location' => 'http://www.example.com' })

          @curl.http_get
          @curl.last_effective_url.should be == 'http://example.com'
        end
      end

      context 'when following redirects' do
        before { @curl.follow_location = true }

        it 'should be the same as #url when no location header is present' do
          stub_request(:any, "example.com")
          @curl.http_get
          @curl.last_effective_url.should be == 'http://example.com'
        end

        it 'should be the value of the location header when present' do
          stub_request(:any, 'example.com').
            to_return(:headers => { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com')

          @curl.http_get
          @curl.last_effective_url.should be == 'http://www.example.com'
        end

        it 'should work with more than one redirect' do
          stub_request(:any, 'example.com').
            to_return(:headers => { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com').
            to_return(:headers => { 'Location' => 'http://blog.example.com' })
          stub_request(:any, 'blog.example.com')

          @curl.http_get
          @curl.last_effective_url.should be == 'http://blog.example.com'
        end

        it 'should maintain the original url' do
          stub_request(:any, 'example.com').
            to_return(:headers => { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com')

          @curl.http_get
          @curl.url.should be == 'http://example.com'
        end

        it 'should have the redirected-to attrs (body, response code)' do
          stub_request(:any, 'example.com').
            to_return(:body => 'request A',
                      :status => 302,
                      :headers => { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com').to_return(:body => 'request B')

          @curl.http_get
          @curl.body_str.should be == 'request B'
          @curl.response_code.should be == 200
        end

        it 'should follow more than one redirect' do
          stub_request(:any, 'example.com').
            to_return(:headers => { 'Location' => 'http://www.example.com' })
          stub_request(:any, 'www.example.com').
            to_return(:headers => { 'Location' => 'http://blog.example.com' })
          stub_request(:any, 'blog.example.com').to_return(:body => 'blog post')

          @curl.http_get
          @curl.url.should be == 'http://example.com'
          @curl.body_str.should be == 'blog post'
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
            to_return(:body     => "abc",
                      :status   => 200,
                      :headers  => { 'Content-Type' => content_type })

          @curl.http_get
          @curl.content_type.should be == content_type
        end
      end

      context "when response does not include Content-Type header" do
        it "returns nil for content_type" do
          content_type = "application/json"

          stub_request(:any, 'example.com').
            to_return(:body     => "abc",
                      :status   => 200 )

          @curl.http_get
          @curl.content_type.should be_nil
        end
      end
    end
  end

  describe "Webmock with Curb" do
    describe "using #http for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::DynamicHttp

      it "should work with uppercase arguments" do
        stub_request(:get, "www.example.com").to_return(:body => "abc")

        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.http(:GET)
        c.body_str.should be == "abc"
      end
    end

    describe "using #http_* methods for requests" do
      it_should_behave_like "Curb"
      include CurbSpecHelper::NamedHttp

      it "should work with blank arguments for post" do
        stub_http_request(:post, "www.example.com").with(:body => "01234")
        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.post_body = "01234"
        c.http_post
        c.response_code.should be == 200
      end

      it "should work with blank arguments for put" do
        stub_http_request(:put, "www.example.com").with(:body => "01234")
        c = Curl::Easy.new
        c.url = "http://www.example.com"
        c.put_data = "01234"
        c.http_put
        c.response_code.should be == 200
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
  end
end
