require 'spec_helper'

describe WebMock::RequestExecutionVerifier do
  before(:each) do
    @verifier = WebMock::RequestExecutionVerifier.new
    @request_pattern = double(WebMock::RequestPattern, to_s: "www.example.com")
    @verifier.request_pattern = @request_pattern
    allow(WebMock::RequestRegistry.instance).to receive(:to_s).and_return("executed requests")
    @executed_requests_info = "\n\nThe following requests were made:\n\nexecuted requests\n" + "="*60
  end

  describe "description" do

    it "reports the description" do
      @verifier.expected_times_executed = 2
      expect(@verifier.description).to eq "request www.example.com 2 times"
    end

    it "reports description correctly when expectation is 1 time" do
      @verifier.expected_times_executed = 1
      expect(@verifier.description).to eq "request www.example.com 1 time"
    end

    context "at_least_times_executed is set" do
      it "reports description correctly when expectation at least 2 times" do
        @verifier.at_least_times_executed = 2
        expect(@verifier.description).to eq "request www.example.com at least 2 times"
      end

      it "reports description correctly when expectation is at least 3 times" do
        @verifier.at_least_times_executed = 3
        expect(@verifier.description).to eq "request www.example.com at least 3 times"
      end
    end

    context "at_most_times_executed is set" do
      it "reports description correctly when expectation is at most 2 times" do
        @verifier.at_most_times_executed = 2
        expect(@verifier.description).to eq "request www.example.com at most 2 times"
      end

      it "reports description correctly when expectation is at most 1 time" do
        @verifier.at_most_times_executed = 1
        expect(@verifier.description).to eq "request www.example.com at most 1 time"
      end
    end

  end

  describe "failure message" do

    it "reports the failure message" do
      @verifier.times_executed = 0
      @verifier.expected_times_executed = 2
      expected_text = "The request www.example.com was expected to execute 2 times but it executed 0 times"
      expected_text += @executed_requests_info
      expect(@verifier.failure_message).to eq(expected_text)
    end

    it "reports failure message correctly when executed times is one" do
      @verifier.times_executed = 1
      @verifier.expected_times_executed = 1
      expected_text = "The request www.example.com was expected to execute 1 time but it executed 1 time"
      expected_text += @executed_requests_info
      expect(@verifier.failure_message).to eq(expected_text)
    end

    context "at_least_times_executed is set" do
      it "reports failure message correctly when executed times is one" do
        @verifier.times_executed = 1
        @verifier.at_least_times_executed = 2
        expected_text = "The request www.example.com was expected to execute at least 2 times but it executed 1 time"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message).to eq(expected_text)
      end

      it "reports failure message correctly when executed times is two" do
        @verifier.times_executed = 2
        @verifier.at_least_times_executed = 3
        expected_text = "The request www.example.com was expected to execute at least 3 times but it executed 2 times"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message).to eq(expected_text)
      end
    end

    context "at_most_times_executed is set" do
      it "reports failure message correctly when executed times is three" do
        @verifier.times_executed = 3
        @verifier.at_most_times_executed = 2
        expected_text = "The request www.example.com was expected to execute at most 2 times but it executed 3 times"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message).to eq(expected_text)
      end

      it "reports failure message correctly when executed times is two" do
        @verifier.times_executed = 2
        @verifier.at_most_times_executed = 1
        expected_text = "The request www.example.com was expected to execute at most 1 time but it executed 2 times"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message).to eq(expected_text)
      end
    end
  end

  describe "failure message for a JSON body declared as a string" do
    before(:each) do
      allow(WebMock::RequestRegistry.instance).to receive(:to_s).and_call_original
      WebMock::RequestRegistry.instance.requested_signatures.put(
        WebMock::RequestSignature.new(:post, "www.example.com",
          body: '{"b":2,"a":1}', headers: {"Content-Type" => "application/json"})
      )
    end

    it "suggests declaring the body as a hash when a request had the same JSON formatted differently" do
      @verifier.request_pattern = WebMock::RequestPattern.new(:post, "www.example.com", body: '{"a":1,"b":2}')
      expect(@verifier.matches?).to be false
      expect(@verifier.failure_message).to include(
        "but it executed 0 times\n\n#{WebMock::JsonBodyHint::EXPECTATION_HINT}\n\nThe following requests were made:"
      )
    end

    it "does not add the hint when the JSON is different" do
      @verifier.request_pattern = WebMock::RequestPattern.new(:post, "www.example.com", body: '{"a":1,"b":3}')
      expect(@verifier.matches?).to be false
      expect(@verifier.failure_message).not_to include("Hint:")
    end

    it "does not call a callable URI again while building the failure message" do
      WebMock::RequestRegistry.instance.requested_signatures.put(
        WebMock::RequestSignature.new(:get, "www.example.com")
      )
      calls = 0
      @verifier.request_pattern = WebMock::RequestPattern.new(:get, ->(_uri) { calls += 1; false })

      expect(@verifier.matches?).to be false
      expect(calls).to eq(1)
      @verifier.failure_message
      expect(calls).to eq(1)
    end

    it "does not add the hint when showing the body diff is turned off" do
      WebMock.hide_body_diff!
      @verifier.request_pattern = WebMock::RequestPattern.new(:post, "www.example.com", body: '{"a":1,"b":2}')
      expect(@verifier.matches?).to be false
      expect(@verifier.failure_message).not_to include("Hint:")
    ensure
      WebMock.show_body_diff!
    end

    context "when the request was made too many times" do
      before(:each) do
        WebMock::RequestRegistry.instance.requested_signatures.put(
          WebMock::RequestSignature.new(:post, "www.example.com",
            body: '{"a":1,"b":2}', headers: {"Content-Type" => "application/json"}), 2
        )
        @verifier.request_pattern = WebMock::RequestPattern.new(:post, "www.example.com", body: '{"a":1,"b":2}')
      end

      it "does not add the hint to an at_most failure" do
        @verifier.at_most_times_executed = 1
        expect(@verifier.matches?).to be false
        expect(@verifier.failure_message).not_to include("Hint:")
      end

      it "does not add the hint to an exact count failure" do
        @verifier.expected_times_executed = 1
        expect(@verifier.matches?).to be false
        expect(@verifier.failure_message).not_to include("Hint:")
      end
    end

    it "adds the hint to an at_least failure with too few requests" do
      @verifier.request_pattern = WebMock::RequestPattern.new(:post, "www.example.com", body: '{"a":1,"b":2}')
      @verifier.at_least_times_executed = 1
      expect(@verifier.matches?).to be false
      expect(@verifier.failure_message).to include(WebMock::JsonBodyHint::EXPECTATION_HINT)
    end

    it "does not add the hint to the negated message" do
      WebMock::RequestRegistry.instance.requested_signatures.put(
        WebMock::RequestSignature.new(:post, "www.example.com",
          body: '{"a":1,"b":2}', headers: {"Content-Type" => "application/json"})
      )
      @verifier.request_pattern = WebMock::RequestPattern.new(:post, "www.example.com", body: '{"a":1,"b":2}')
      expect(@verifier.does_not_match?).to be false
      expect(@verifier.failure_message_when_negated).not_to include("Hint:")
    end
  end

  describe "negative failure message" do

    it "reports failure message if it executed number of times specified" do
      @verifier.times_executed = 2
      @verifier.expected_times_executed = 2
      expected_text = "The request www.example.com was not expected to execute 2 times but it executed 2 times"
      expected_text += @executed_requests_info
      expect(@verifier.failure_message_when_negated).to eq(expected_text)
    end

    it "reports failure message when not expected request but it executed" do
      @verifier.times_executed = 1
      expected_text = "The request www.example.com was not expected to execute but it executed 1 time"
      expected_text += @executed_requests_info
      expect(@verifier.failure_message_when_negated).to eq(expected_text)
    end

    context "at_least_times_executed is set" do
      it "reports failure message correctly when executed times is one" do
        @verifier.times_executed = 3
        @verifier.at_least_times_executed = 2
        expected_text = "The request www.example.com was not expected to execute at least 2 times but it executed 3 times"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message_when_negated).to eq(expected_text)
      end

      it "reports failure message correctly when executed times is two" do
        @verifier.times_executed = 2
        @verifier.at_least_times_executed = 2
        expected_text = "The request www.example.com was not expected to execute at least 2 times but it executed 2 times"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message_when_negated).to eq(expected_text)
      end
    end

    context "at_most_times_executed is set" do
      it "reports failure message correctly when executed times is three" do
        @verifier.times_executed = 2
        @verifier.at_most_times_executed = 3
        expected_text = "The request www.example.com was not expected to execute at most 3 times but it executed 2 times"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message_when_negated).to eq(expected_text)
      end

      it "reports failure message correctly when executed times is one" do
        @verifier.times_executed = 1
        @verifier.at_most_times_executed = 2
        expected_text = "The request www.example.com was not expected to execute at most 2 times but it executed 1 time"
        expected_text += @executed_requests_info
        expect(@verifier.failure_message_when_negated).to eq(expected_text)
      end
    end

  end

  describe "matches?" do

    it "succeeds if request was executed expected number of times" do
      expect(WebMock::RequestRegistry.instance).
        to receive(:times_executed).with(@request_pattern).and_return(10)
      @verifier.expected_times_executed = 10
      expect(@verifier.matches?).to be_truthy
    end

    it "fails if request was not executed expected number of times" do
      expect(WebMock::RequestRegistry.instance).
        to receive(:times_executed).with(@request_pattern).and_return(10)
      @verifier.expected_times_executed = 5
      expect(@verifier.matches?).to be_falsey
    end

  end

  describe "does_not_match?" do

    it "fails if request executed expected number of times" do
      expect(WebMock::RequestRegistry.instance).
        to receive(:times_executed).with(@request_pattern).and_return(10)
      @verifier.expected_times_executed = 10
      expect(@verifier.does_not_match?).to be_falsey
    end

    it "succeeds if request was not executed at all and expected number of times was not set" do
      expect(WebMock::RequestRegistry.instance).
        to receive(:times_executed).with(@request_pattern).and_return(0)
      expect(@verifier.does_not_match?).to be_truthy
    end

    it "fails if request was executed and expected number of times was not set" do
      expect(WebMock::RequestRegistry.instance).
        to receive(:times_executed).with(@request_pattern).and_return(1)
      expect(@verifier.does_not_match?).to be_falsey
    end

    it "succeeds if request was not executed expected number of times" do
      expect(WebMock::RequestRegistry.instance).
        to receive(:times_executed).with(@request_pattern).and_return(10)
      @verifier.expected_times_executed = 5
      expect(@verifier.does_not_match?).to be_truthy
    end

  end

end
