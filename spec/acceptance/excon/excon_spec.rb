require 'spec_helper'
require 'acceptance/webmock_shared'
require 'acceptance/excon/excon_spec_helper'

describe "Excon" do
  include ExconSpecHelper
  include_context "with WebMock", :no_url_auth

  it 'should allow Excon requests to use query hash paramters' do
    stub_request(:get, "http://example.com/resource/?a=1&b=2").to_return(body: "abc")
    expect(Excon.new('http://example.com').get(path: "resource/", query: {a: 1, b: 2}).body).to eq("abc")
  end

  it 'should support Excon :expects options' do
    stub_request(:get, "http://example.com/").to_return(body: 'a')
    expect { Excon.new('http://example.com').get(expects: 204) }.to raise_error(Excon::Errors::OK)
  end

  context "with response_block" do
    it "should support excon response_block for real requests", net_connect: true do
      a = []
      WebMock.allow_net_connect!
      r = Excon.new('http://httpstat.us/200', headers: { "Accept" => "*" }).
        get(response_block: lambda {|e, remaining, total| a << e}, chunk_size: 1)
      expect(a).to eq(["2", "0", "0", " ", "O", "K"])
      expect(r.body).to eq("")
    end

    it "should support excon response_block" do
      a = []
      stub_request(:get, "http://example.com/").to_return(body: "abc")
      r = Excon.new('http://example.com').get(response_block: lambda {|e, remaining, total| a << e}, chunk_size: 1)
      expect(a).to eq(['a', 'b', 'c'])
      expect(r.body).to eq("")
    end

    it "should invoke callbacks with response body even if a real request is made", net_connect: true do
      a = []
      WebMock.allow_net_connect!
      response = nil
      WebMock.after_request { |_, res|
        response = res
      }
      r = Excon.new('http://httpstat.us/200', headers: { "Accept" => "*" }).
        get(response_block: lambda {|e, remaining, total| a << e}, chunk_size: 1)
      expect(response.body).to eq("200 OK")
      expect(a).to eq(["2", "0", "0", " ", "O", "K"])
      expect(r.body).to eq("")
    end
  end

  let(:file) { File.new(__FILE__) }
  let(:file_contents) { File.read(__FILE__) }

  it 'handles file uploads correctly' do
    stub_request(:put, "http://example.com/upload").with(body: file_contents)

    yielded_request_body = nil
    WebMock.after_request do |req, res|
      yielded_request_body = req.body
    end

    Excon.new("http://example.com").put(path: "upload", body: file)

    expect(yielded_request_body).to eq(file_contents)
  end

  describe '.request_params_from' do

    it 'rejects invalid request keys' do
      request_params = WebMock::HttpLibAdapters::ExconAdapter.request_params_from(body: :keep, fake: :reject)
      expect(request_params).to eq(body: :keep)
    end

  end

end
