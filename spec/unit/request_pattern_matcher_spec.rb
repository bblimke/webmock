require 'spec_helper'

describe WebMock::RequestPatternMatcher do
  def request(body, uri = "http://www.example.com/", headers = {})
    signature = WebMock::RequestSignature.new(:post, uri, body: body, headers: headers)
    WebMock::RequestRegistry.instance.requested_signatures.put(signature)
    signature
  end

  describe "#with" do
    let!(:stub) { stub_request(:post, "www.example.com") }

    before do
      request("abc")
      request("def")
    end

    it "counts only the requests that also match the given conditions" do
      expect(stub).to have_been_requested.once.with(body: "abc")
      expect(stub).to have_been_requested.once.with(body: "def")
      expect(stub).not_to have_been_requested.with(body: "xyz")
    end

    it "does not change the stub" do
      expect(stub).to have_been_requested.once.with(body: "abc")

      expect(stub).to have_been_requested.twice
      expect(stub.to_s).to eq("POST http://www.example.com/")
      expect(stub.request_pattern.matches?(request("xyz"))).to be true
    end

    it "keeps a block given to the stub" do
      stub_with_block = stub_request(:post, "www.example.com").with { |r| r.body == "abc" }

      expect(stub_with_block).to have_been_requested.once.with(headers: {})
      expect(stub_with_block).not_to have_been_requested.with(body: "def")
    end

    it "accepts a block as a condition" do
      expect(stub).to have_been_requested.once.with { |r| r.body == "def" }
    end

    it "does not add a query to the stub" do
      query_stub = stub_request(:post, %r{www.example.com/search})
      request("abc", "http://www.example.com/search?q=1")
      request("abc", "http://www.example.com/search?q=2")

      expect(query_stub).to have_been_requested.once.with(query: {"q" => "1"})
      expect(query_stub).to have_been_requested.twice
    end

    it "works with a_request" do
      expect(a_request(:post, "www.example.com")).to have_been_made.once.with(body: "abc")
    end

    it "keeps earlier conditions when called again" do
      request("abc", "http://www.example.com/", "X" => "1")
      request("def", "http://www.example.com/", "X" => "1")

      expect(stub).to have_been_requested.once.with(body: "abc").with(headers: {"X" => "1"})
      expect(stub).not_to have_been_requested.with(body: "xyz").with(headers: {"X" => "1"})
    end

    it "describes the conditions apart from the stub in the failure message" do
      stub_with_body = stub_request(:post, "www.example.com").with(body: "abc")
      matcher = have_been_requested.with(body: "xyz")

      expect(matcher.matches?(stub_with_body)).to be false
      expect(matcher.failure_message).to start_with(
        'The request POST http://www.example.com/ with body "abc" (only requests with body "xyz") ' \
        'was expected to execute 1 time but it executed 0 times'
      )
    end

    it "describes query conditions in the failure message" do
      matcher = have_been_requested.with(query: {"q" => "1"}).with(body: "abc")

      expect(matcher.matches?(stub)).to be false
      expect(matcher.failure_message).to start_with(
        "The request POST http://www.example.com/ (only requests with query params #{{"q" => "1"}} with body \"abc\") " \
        "was expected to execute 1 time but it executed 0 times"
      )
    end

    it "describes the conditions in the negated failure message" do
      matcher = have_been_requested.with(body: "abc")

      expect(matcher.does_not_match?(stub)).to be false
      expect(matcher.failure_message_when_negated).to start_with(
        'The request POST http://www.example.com/ (only requests with body "abc") ' \
        'was not expected to execute but it executed 1 time'
      )
    end

    describe "JSON body hint" do
      let(:json) { {"Content-Type" => "application/json"} }
      let(:json_pattern) { a_request(:post, "www.example.com").with(body: '{"a":1,"b":2}') }

      before do
        request('{"b":2,"a":1}', "http://www.example.com/", json)
      end

      def failure_message_for(matcher, pattern)
        expect(matcher.matches?(pattern)).to be false
        matcher.failure_message
      end

      it "is shown when the JSON body given to with differs only in formatting" do
        expect(failure_message_for(have_been_requested.with(body: '{"a":1,"b":2}'), stub)).
          to include(WebMock::JsonBodyHint::EXPECTATION_HINT)
      end

      it "is still shown for a pattern's JSON body when other conditions are given" do
        expect(failure_message_for(have_been_made.with(headers: json), json_pattern)).
          to include(WebMock::JsonBodyHint::EXPECTATION_HINT)
      end

      it "is not shown when the other conditions do not match the request" do
        expect(failure_message_for(have_been_made.with(headers: {"X" => "1"}), json_pattern)).
          not_to include("Hint:")
      end

      it "does not call a block given to with while building the failure message" do
        matcher = have_been_made.with { |_request| raise "the block should not be called" }
        expect(failure_message_for(matcher, json_pattern)).not_to include("Hint:")
      end

      it "is not shown when the other conditions declare a body too" do
        expect(failure_message_for(have_been_made.with(body: '{"b":2,"a":1}'), json_pattern)).
          not_to include("Hint:")
      end

      it "is not shown when the JSON is different" do
        expect(failure_message_for(have_been_requested.with(body: '{"a":1,"b":3}'), stub)).
          not_to include("Hint:")
      end
    end

    it "raises when called without conditions" do
      expect { have_been_requested.with }.to raise_error(ArgumentError, /#with method invoked with no arguments/)
    end
  end
end
