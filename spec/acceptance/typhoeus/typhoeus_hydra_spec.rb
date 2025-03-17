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
