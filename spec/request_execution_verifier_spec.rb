require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe RequestExecutionVerifier do
  before(:each) do
    @verifier = RequestExecutionVerifier.new
    @request_profile = mock(RequestProfile, :to_s => "www.google.com")
    @verifier.request_profile = @request_profile
  end


  describe "failure message" do

    it "should report failure message" do
      @verifier.times_executed = 0
      @verifier.expected_times_executed = 2
      @verifier.failure_message.should == "The request www.google.com was expected to execute 2 times but it executed 0 times"
    end

    it "should report failure message correctly when executed times is one" do
      @verifier.times_executed = 1
      @verifier.expected_times_executed = 1
      @verifier.failure_message.should == "The request www.google.com was expected to execute 1 time but it executed 1 time"
    end

  end

  describe "verify" do

    it "should succeed if request was executed expected number of times" do
      RequestRegistry.instance.
        should_receive(:times_executed).with(@request_profile).and_return(10)
      @verifier.expected_times_executed = 10
      @verifier.verify.should be_true
    end

    it "should fail if request was not executed expected number of times" do
      RequestRegistry.instance.
        should_receive(:times_executed).with(@request_profile).and_return(10)
      @verifier.expected_times_executed = 5
      @verifier.verify.should be_false
    end

  end

  def verify
    @times_executed =
    RequestRegistry.instance.times_executed(@request_profile)
    @times_executed == @expected_times_executed
  end

end
