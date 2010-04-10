module WebMock
  class RequestExecutionVerifier

    attr_accessor :request_pattern, :expected_times_executed, :times_executed

    def initialize(request_pattern = nil, expected_times_executed = nil)
      @request_pattern = request_pattern
      @expected_times_executed = expected_times_executed
    end

    def matches?
      @times_executed =
      RequestRegistry.instance.times_executed(@request_pattern)
      @times_executed == (@expected_times_executed || 1)
    end

    def does_not_match?
      @times_executed =
      RequestRegistry.instance.times_executed(@request_pattern)
      if @expected_times_executed
        @times_executed != @expected_times_executed
      else
        @times_executed == 0
      end
    end


    def failure_message
      expected_times_executed = @expected_times_executed || 1
      %Q(The request #{request_pattern.to_s} was expected to execute #{expected_times_executed} time#{ (expected_times_executed == 1) ? '' : 's'} but it executed #{times_executed} time#{ (times_executed == 1) ? '' : 's'})
    end

    def negative_failure_message
      if @expected_times_executed
        %Q(The request #{request_pattern.to_s} was not expected to execute #{expected_times_executed} time#{ (expected_times_executed == 1) ? '' : 's'} but it executed #{times_executed} time#{ (times_executed == 1) ? '' : 's'})
      else
        %Q(The request #{request_pattern.to_s} was expected to execute 0 times but it executed #{times_executed} time#{ (times_executed == 1) ? '' : 's'})
      end
    end

  end
end
