# encoding: utf-8

require "spec_helper"
require "acceptance/webmock_shared"
require "acceptance/http_rb/http_rb_spec_helper"

describe "HTTP.rb" do
  include HttpRbSpecHelper

  include_examples "with WebMock", :no_status_message

  context "streaming body" do
    let(:response) { HTTP.get "http://example.com" }
    before { stub_simple_request "example.com", 302, {}, "abc" }

    it "works as if it was streamed from socket" do
      expect(response.body.readpartial 1).to eq "a"
    end

    it "fails if body was already streamed" do
      response.body.to_s
      expect { response.body.readpartial 1 }.to raise_error(HTTP::StateError)
    end
  end

  context "without following redirects" do
    let(:response) { http_request(:get, "http://example.com") }
    let(:headers)  { response.headers }

    it "stops on first request" do
      stub_simple_request("example.com", 302, "Location" => "http://www.example.com")
      stub_simple_request("www.example.com")

      expect(headers).to include "Host" => "example.com"
    end
  end

  context "following redirects" do
    let(:options)  { { follow: true } }
    let(:response) { http_request(:get, "http://example.com", options) }
    let(:headers)  { response.headers }

    it "returns response of destination" do
      stub_simple_request("example.com", 302, "Location" => "http://www.example.com")
      stub_simple_request("www.example.com")

      expect(headers).to include "Host" => "www.example.com"
    end
  end

  context "restored request uri on replayed response object" do
    it "keeps non-default port" do
      stub_request :get, "example.com:1234/foo"
      response = HTTP.get "http://example.com:1234/foo"

      expect(response.uri.to_s).to eq "http://example.com:1234/foo"
    end

    it "does not injects default port" do
      stub_request :get, "example.com/foo"
      response = HTTP.get "http://example.com/foo"

      expect(response.uri.to_s).to eq "http://example.com/foo"
    end

    it "strips out default port even if it was explicitly given" do
      stub_request :get, "example.com/foo"
      response = HTTP.get "http://example.com:80/foo"

      expect(response.uri.to_s).to eq "http://example.com/foo"
    end
  end

  context "streamer" do
    it "can be read to a provided buffer" do
      stub_request(:get, "example.com/foo")
        .to_return(status: 200, body: "Hello world! ")
      response = HTTP.get "http://example.com/foo"

      buffer = ""
      response.body.readpartial(1024, buffer)

      expect(buffer).to eq "Hello world! "
    end

    it "can be closed" do
      stub_request :get, "example.com/foo"
      response = HTTP.get "http://example.com/foo"

      response.connection.close
    end

    it "reports request finish" do
      stub_request(:get, "example.com/foo")
        .to_return(body: 'XX')
      response = HTTP.get "http://example.com/foo"

      expect(response.connection.finished_request?).to be(false)

      response.body.readpartial(1)
      expect(response.connection.finished_request?).to be(false)

      response.body.readpartial
      expect(response.connection.finished_request?).to be(true)
    end
  end

  it "should preserve request body encoding when matching requests" do
    stub_request(:post, "www.example.com").with(body: (lambda {|body|
      body.encoding == Encoding::UTF_8
    }))
    http_request(:post, "http://www.example.com/", body: "abc")
  end

  describe "when making real requests", net_connect: true do
    before do
      WebMock.allow_net_connect!
    end

    it "should allow streaming the response body" do
      response = HTTP.get("http://localhost:#{WebMockServer.instance.port}")

      read_body = ""
      response.body.each do |chunk|
        read_body << chunk
      end

      expect(read_body).to eql("hello world")
    end
  end
end
