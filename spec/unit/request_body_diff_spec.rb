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
      method, uri, {body: request_stub_body}
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

    context "request stub body pattern has a value that matches with ===" do
      let(:request_stub_body) { { "email" => /@/, "name" => "John", "tags" => [/a/] } }
      let(:request_signature_body) { {"email" => "a@b.c", "name" => "Jane", "tags" => ["abc"]}.to_json }

      it "leaves out the values the pattern matches" do
        expect(subject.body_diff).to eq(
          [["~", "name", "Jane", "John"]]
        )
      end
    end

    context "request stub body pattern has a lambda" do
      let(:request_stub_body) { { "id" => ->(_id) { raise "the diff ran the lambda" } } }
      let(:request_signature_body) { {"id" => "abc"}.to_json }

      it "doesn't call it" do
        expect(subject.body_diff.map(&:first)).to eq(["~"])
      end
    end

    context "request stub body pattern has a matcher of its own" do
      # An RSpec expectation failure isn't a StandardError.
      let(:matcher) do
        Object.new.tap do |m|
          m.define_singleton_method(:===) { |_value| raise RSpec::Expectations::ExpectationNotMetError, "the diff ran the matcher" }
        end
      end
      let(:request_stub_body) { { "id" => matcher } }
      let(:request_signature_body) { {"id" => "abc"}.to_json }

      it "doesn't run it" do
        expect(subject.body_diff.map(&:first)).to eq(["~"])
      end
    end

    context "request stub body pattern has a key with a null value" do
      let(:request_stub_body) { { "middle" => nil } }
      let(:request_signature_body) { {"extra" => nil}.to_json }

      it "shows the missing and the unexpected key" do
        expect(subject.body_diff.map { |change, key, *| [change, key] }).to contain_exactly(["-", "extra"], ["+", "middle"])
      end
    end

    context "request stub body pattern has a regexp in an encoding incompatible with the request's value" do
      let(:request_stub_body) { { "name" => Regexp.new("\xFF".b) } }
      let(:request_signature_body) { {"name" => "caf\u00E9"}.to_json }

      it "shows the value as a difference" do
        expect(subject.body_diff.map(&:first)).to eq(["~"])
      end
    end

    context "request stub body pattern has a regexp that does not match" do
      let(:request_stub_body) { { "email" => /@/ } }
      let(:request_signature_body) { {"email" => "nope"}.to_json }

      it "generates a diff" do
        expect(subject.body_diff).to eq(
          [["~", "email", "nope", /@/]]
        )
      end
    end

    context "request signature has a +json content type" do
      before :each do
        request_signature.headers = {"Content-Type" => "application/vnd.api+json"}
      end

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
