require 'spec_helper'
require 'acceptance/webmock_shared'

if RUBY_PLATFORM =~ /java/
  require 'acceptance/manticore/manticore_spec_helper'

  describe "Manticore" do
    include ManticoreSpecHelper

    include_context "with WebMock", :no_status_message

    context "calling http methods on Manticore directly using Manticore's facade" do
      it "handles GET" do
        stub_request(:get, "http://example-foo.com").to_return(:status => 301)
        response = Manticore.get("http://example-foo.com")
        expect(response.code).to eq(301)
      end

      it "handles POST" do
        stub_request(:post, "http://example-foo.com").to_return(:status => 201)
        response = Manticore.post("http://example-foo.com", {:hello => "world"})
        expect(response.code).to eq(201)
      end

      it "handles PUT" do
        stub_request(:put, "http://example-foo.com").to_return(:status => 409)
        response = Manticore.put("http://example-foo.com", {:hello => "world"})
        expect(response.code).to eq(409)
      end

      it "handles PATCH" do
        stub_request(:patch, "http://example-foo.com").to_return(:status => 409)
        response = Manticore.patch("http://example-foo.com", {:hello => "world"})
        expect(response.code).to eq(409)
      end

      it "handles DELETE" do
        stub_request(:delete, "http://example-foo.com").to_return(:status => 204)
        response = Manticore.delete("http://example-foo.com", {:id => 1})
        expect(response.code).to eq(204)
      end

      it "handles OPTIONS" do
        stub_request(:options, "http://example-foo.com").to_return(:status => 200)
        response = Manticore.options("http://example-foo.com")
        expect(response.code).to eq(200)
      end

      it "handles HEAD" do
        stub_request(:head, "http://example-foo.com").to_return(:status => 204)
        response = Manticore.head("http://example-foo.com")
        expect(response.code).to eq(204)
      end
    end
  end
end
