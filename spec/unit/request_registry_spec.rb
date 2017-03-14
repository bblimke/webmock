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

end
