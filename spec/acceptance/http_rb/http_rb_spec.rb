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
      expect { response.body.readpartial 1 }.to raise_error
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
    let(:options)  { { :follow => true } }
    let(:response) { http_request(:get, "http://example.com", options) }
    let(:headers)  { response.headers }

    it "returns response of destination" do
      stub_simple_request("example.com", 302, "Location" => "http://www.example.com")
      stub_simple_request("www.example.com")

      expect(headers).to include "Host" => "www.example.com"
    end
  end

  it "restores request uri on replayed response object" do
    uri = Addressable::URI.parse "http://example.com/foo"

    stub_request :get, "example.com/foo"
    response = HTTP.get uri

    expect(response.uri.to_s).to eq uri.to_s
  end
end
