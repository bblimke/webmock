require 'spec_helper'

RSpec.describe WebMock::RequestBodyDiff do
  subject { WebMock::RequestBodyDiff.new(request_signature, request_stub) }

  let(:uri) { "http://example.com" }
  let(:method) { "GET" }

  let(:request_stub) { WebMock::RequestStub.new(method, uri) }
  let(:request_signature) { WebMock::RequestSignature.new(method, uri) }

  let(:request_stub_body) { { "key" => "value"} }
  let(:request_signature_body) { {"key" => "different value"}.to_json }

  let(:request_pattern) {
    WebMock::RequestPattern.new(
      method, uri, {:body => request_stub_body}
    )
  }

  before :each do
    request_stub.request_pattern = request_pattern
    request_signature.headers = {"Content-Type" => "application/json"}
    request_signature.body = request_signature_body
  end

  describe "#body_diff" do
    context "request signature is unparseable json" do
      let(:request_signature_body) { "youcan'tparsethis!" }

      it "returns an empty hash" do
        expect(subject.body_diff).to eq({})
      end
    end

    context "request stub body as unparseable json" do
      let(:request_stub_body) { "youcan'tparsethis!" }

      it "returns an empty hash" do
        expect(subject.body_diff).to eq({})
      end
    end

    context "request stub body pattern is hash" do
      let(:request_stub_body) { { "key" => "value"} }

      it "generates a diff" do
        expect(subject.body_diff).to eq(
          [["~", "key", "different value", "value"]]
        )
      end
    end

    context "request signature doesn't have json headers" do
      before :each do
        request_signature.headers = {"Content-Type" => "application/xml"}
      end

      it "returns an empty hash" do
        expect(subject.body_diff).to eq({})
      end
    end

    context "request stub body pattern is a string" do
      let(:request_stub_body) { { "key" => "value"}.to_json }

      it "generates a diff" do
        expect(subject.body_diff).to eq(
          [["~", "key", "different value", "value"]]
        )
      end
    end

    context "stub request has no request pattern" do
      let(:request_signature_body) { nil }

      it "returns an empty hash" do
        expect(subject.body_diff).to eq({})
      end
    end

    context "stub request has no body pattern" do
      let(:request_stub_body) { nil }

      it "returns an empty hash" do
        expect(subject.body_diff).to eq({})
      end
    end
  end
end
