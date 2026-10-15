require 'spec_helper'

describe WebMock::RequestRegistry do

  before(:each) do
    WebMock::RequestRegistry.instance.reset!
    @request_pattern = WebMock::RequestPattern.new(:get, "www.example.com")
    @request_signature = WebMock::RequestSignature.new(:get, "www.example.com")
  end

  describe "reset!" do
    before(:each) do
      WebMock::RequestRegistry.instance.requested_signatures.put(@request_signature)
    end

    it "should clean list of executed requests" do
      expect(WebMock::RequestRegistry.instance.times_executed(@request_pattern)).to eq(1)
      WebMock::RequestRegistry.instance.reset!
      expect(WebMock::RequestRegistry.instance.times_executed(@request_pattern)).to eq(0)
    end

  end

  describe "times executed" do

    before(:each) do
      @request_stub1 = WebMock::RequestStub.new(:get, "www.example.com")
      @request_stub2 = WebMock::RequestStub.new(:get, "www.example.net")
      @request_stub3 = WebMock::RequestStub.new(:get, "www.example.org")
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.com"))
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.com"))
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.org"))
    end

    it "should report 0 if no request matching pattern was requested" do
      expect(WebMock::RequestRegistry.instance.times_executed(WebMock::RequestPattern.new(:get, "www.example.net"))).to eq(0)
    end

    it "should report number of times matching pattern was requested" do
      expect(WebMock::RequestRegistry.instance.times_executed(WebMock::RequestPattern.new(:get, "www.example.com"))).to eq(2)
    end

    it "should report number of times all matching pattern were requested" do
      expect(WebMock::RequestRegistry.instance.times_executed(WebMock::RequestPattern.new(:get, /.*example.*/))).to eq(3)
    end

    describe "multithreading" do
      let(:request_pattern) { WebMock::RequestPattern.new(:get, "www.example.com") }

      # Reproduce a multithreading issue that causes a RuntimeError:
      #   can't add a new key into hash during iteration.
      it "works normally iterating on the requested signature hash while another thread is setting it" do
        thread_injected = false
        allow(request_pattern).to receive(:matches?).and_wrap_original do |m, *args|
          unless thread_injected
            thread_injected = true
            Thread.new { WebMock::RequestRegistry.instance.requested_signatures.put(:abc) }.join(0.1)
          end
          m.call(*args)
        end
        expect(WebMock::RequestRegistry.instance.times_executed(request_pattern)).to eq(2)
        sleep 0.1 while !WebMock::RequestRegistry.instance.requested_signatures.hash.key?(:abc)
      end
    end
  end

  describe "request_signatures" do
    it "should return hash of unique request signatures with accumulated number" do
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.com"))
      WebMock::RequestRegistry.instance.requested_signatures.put(WebMock::RequestSignature.new(:get, "www.example.com"))
      expect(WebMock::RequestRegistry.instance.requested_signatures.
        get(WebMock::RequestSignature.new(:get, "www.example.com"))).to eq(2)
    end
  end

  describe "to_s" do
    it "should output string with all executed requests and numbers of executions" do
      [
        WebMock::RequestSignature.new(:get, "www.example.com"),
        WebMock::RequestSignature.new(:get, "www.example.com"),
        WebMock::RequestSignature.new(:put, "www.example.org"),
      ].each do |s|
        WebMock::RequestRegistry.instance.requested_signatures.put(s)
      end
      expect(WebMock::RequestRegistry.instance.to_s).to eq(
      "GET http://www.example.com/ was made 2 times\nPUT http://www.example.org/ was made 1 time\n"
      )
    end

    it "should output info if no requests were executed" do
      expect(WebMock::RequestRegistry.instance.to_s).to eq("No requests were made.")
    end
  end

  describe "executed_requests" do
    let(:registry) { WebMock::RequestRegistry.instance }

    it "lists every request put through the registry, in order, repeats included" do
      other_request = WebMock::RequestSignature.new(:put, "www.example.org")
      registry.put(@request_signature)
      registry.put(other_request)
      registry.put(@request_signature)
      expect(registry.executed_requests).to eq([@request_signature, other_request, @request_signature])
      expect(registry.times_executed(@request_pattern)).to eq(2)
    end

    it "returns a frozen copy" do
      registry.put(@request_signature)
      requests = registry.executed_requests
      registry.put(@request_signature)
      expect(requests).to be_frozen
      expect(requests.size).to eq(1)
    end

    it "returns copies, so changing one does not change WebMock's records" do
      registry.put(WebMock::RequestSignature.new(:get, "www.example.com", headers: {"X" => "1"}))
      registry.executed_requests.first.headers["X"] = "2"
      expect(registry.executed_requests.first.headers["X"]).to eq("1")
      expect(registry.times_executed(WebMock::RequestPattern.new(:get, "www.example.com", headers: {"X" => "1"}))).to eq(1)
    end

    it "keeps the body a request had when it was made, even if the caller reuses its buffer" do
      buffer = +"first"
      registry.put(WebMock::RequestSignature.new(:post, "www.example.com", body: buffer))
      buffer.replace("second")
      expect(registry.executed_requests.first.body).to eq("first")
    end

    it "returns nil from put" do
      expect(registry.put(@request_signature)).to be_nil
    end

    it "does not deadlock when a matcher block reads the list while another thread records a request" do
      registry.put(@request_signature)
      inside = Queue.new
      go = Queue.new
      pattern = WebMock::RequestPattern.new(:get, "www.example.com").with { |_| inside << true; go.pop; registry.executed_requests; true }
      matcher = Thread.new { registry.times_executed(pattern) }
      inside.pop
      recorder = Thread.new { registry.put(@request_signature) }
      sleep 0.1
      go << true
      expect(matcher.join(5)).to be_truthy
      expect(recorder.join(5)).to be_truthy
    ensure
      # Without this, a deadlock would hang the rest of the suite.
      [matcher, recorder].compact.each(&:kill)
    end

    it "makes a reset wait until a request is recorded in both the counter and the list" do
      counter = registry.requested_signatures
      between_updates = Queue.new
      finish = Queue.new
      allow(counter).to receive(:put).and_wrap_original do |put, *args|
        stored = put.call(*args)
        between_updates << true
        finish.pop
        stored
      end
      recorder = Thread.new { registry.put(@request_signature) }
      between_updates.pop
      resetter = Thread.new { registry.reset! }
      sleep 0.1
      expect(resetter).to be_alive
      finish << true
      [recorder, resetter].each(&:join)
      expect(registry.times_executed(@request_pattern)).to eq(0)
      expect(registry.executed_requests).to eq([])
    end

    it "lets a Timeout stop a thread waiting to record a request" do
      lock = registry.instance_variable_get(:@lock)
      lock.lock
      waiter = Thread.new do
        Timeout.timeout(0.2) { registry.put(@request_signature) }
      rescue Timeout::Error
        :timed_out
      end
      expect(waiter.join(5)&.value).to eq(:timed_out)
    ensure
      lock.unlock if lock&.owned?
      # If the Timeout did not fire, let the waiter finish before the next example.
      waiter&.join(5)
      registry.reset!
    end

    it "keeps the counter and the list in step when requests come from several threads" do
      10.times.map { Thread.new { 50.times { registry.put(@request_signature) } } }.each(&:join)
      expect(registry.executed_requests.size).to eq(500)
      expect(registry.times_executed(@request_pattern)).to eq(500)
    end

    it "is emptied by reset!" do
      registry.put(@request_signature)
      registry.reset!
      expect(registry.executed_requests).to eq([])
    end
  end
end
