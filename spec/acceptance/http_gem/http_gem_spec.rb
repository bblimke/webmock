# encoding: utf-8

require "spec_helper"
require "acceptance/webmock_shared"
require "acceptance/http_gem/http_gem_spec_helper"

describe "HTTP Gem" do

  include HttpGemSpecHelper


  include_examples "with WebMock", :no_status_message


  context "when not following redirects" do

    let(:response) { http_request(:get, "http://example.com") }
    let(:headers)  { response.headers }

    it "stops on first request" do
      stub_simple_request("example.com", 302, "Location" => "www.example.com")
      stub_simple_request("www.example.com")

      expect(headers).to include "Host" => "example.com"
    end

  end


  context "when following redirects" do

    let(:response) { http_request(:get, "http://example.com", :follow => true) }
    let(:headers)  { response.headers }


    it "returns response of destination" do
      stub_simple_request("example.com", 302, "Location" => "www.example.com")
      stub_simple_request("www.example.com")

      expect(headers).to include "Host" => "www.example.com"
    end


    it "works with more than one redirect" do
      stub_simple_request("example.com", 302, "Location" => "www.example.com")
      stub_simple_request("www.example.com", 302, "Location" => "blog.example.com")
      stub_simple_request("blog.example.com")

      expect(headers).to include "Host" => "blog.example.com"
    end

  end

end
