require 'spec_helper'
require 'acceptance/webmock_shared'

if RUBY_PLATFORM =~ /java/
  require 'acceptance/manticore/manticore_spec_helper'

  describe "Manticore" do
    include ManticoreSpecHelper

    include_context "with WebMock", :no_status_message

    context "calling http methods on Manticore directly using Manticore's facade" do
      it "handles GET" do
        stub_request(:get, "http://example-foo.com").to_return(status: 301)
        response = Manticore.get("http://example-foo.com")
        expect(response.code).to eq(301)
      end

      it "handles POST" do
        stub_request(:post, "http://example-foo.com").to_return(status: 201)
        response = Manticore.post("http://example-foo.com", {hello: "world"})
        expect(response.code).to eq(201)
      end

      it "handles PUT" do
        stub_request(:put, "http://example-foo.com").to_return(status: 409)
        response = Manticore.put("http://example-foo.com", {hello: "world"})
        expect(response.code).to eq(409)
      end

      it "handles PATCH" do
        stub_request(:patch, "http://example-foo.com").to_return(status: 409)
        response = Manticore.patch("http://example-foo.com", {hello: "world"})
        expect(response.code).to eq(409)
      end

      it "handles DELETE" do
        stub_request(:delete, "http://example-foo.com").to_return(status: 204)
        response = Manticore.delete("http://example-foo.com", {id: 1})
        expect(response.code).to eq(204)
      end

      it "handles OPTIONS" do
        stub_request(:options, "http://example-foo.com").to_return(status: 200)
        response = Manticore.options("http://example-foo.com")
        expect(response.code).to eq(200)
      end

      it "handles HEAD" do
        stub_request(:head, "http://example-foo.com").to_return(status: 204)
        response = Manticore.head("http://example-foo.com")
        expect(response.code).to eq(204)
      end

      context "when a custom failure handler is defined" do
        let(:failure_handler) { proc {} }

        before do
          allow(failure_handler).to receive(:call).with(kind_of(Manticore::Timeout)) do |ex|
            raise ex
          end
        end

        it "handles timeouts by invoking the failure handler" do
          stub_request(:get, "http://example-foo.com").to_timeout
          request = Manticore.get("http://example-foo.com").tap do |req|
            req.on_failure(&failure_handler)
          end
          expect { request.call }.to raise_error(Manticore::Timeout)
          expect(failure_handler).to have_received(:call)
        end
      end
    end
  end
end
