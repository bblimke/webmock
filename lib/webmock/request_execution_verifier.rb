module WebMock
  class RequestExecutionVerifier

    attr_accessor :request_pattern, :expected_times_executed, :times_executed, :at_least_times_executed, :at_most_times_executed

    def initialize(request_pattern = nil, expected_times_executed = nil, at_least_times_executed = nil, at_most_times_executed = nil)
      @request_pattern = request_pattern
      @expected_times_executed = expected_times_executed
      @at_least_times_executed = at_least_times_executed
      @at_most_times_executed = at_most_times_executed
    end

    def matches?
      @times_executed =
        RequestRegistry.instance.times_executed(@request_pattern)

      if @at_least_times_executed
        @times_executed >= @at_least_times_executed
      elsif @at_most_times_executed
        @times_executed <= @at_most_times_executed
      else
        @times_executed == (@expected_times_executed || 1)
      end
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

    def description
      "request #{request_pattern.to_s} #{quantity_phrase.strip}"
    end

    def failure_message
      failure_message_phrase(is_negated=false)
    end

    def failure_message_when_negated
      failure_message_phrase(is_negated=true)
    end

    def self.executed_requests_message
      "\n\nThe following requests were made:\n\n#{RequestRegistry.instance.to_s}\n" + "="*60
    end

    private

    def failure_message_phrase(is_negated=false)
      negation = is_negated ? "was not" : "was"
      text = "The request #{request_pattern.to_s} #{negation} expected to execute #{quantity_phrase(is_negated)}but it executed #{times(times_executed)}"
      text << self.class.executed_requests_message
      text
    end

    def quantity_phrase(is_negated=false)
      if @at_least_times_executed
        "at least #{times(@at_least_times_executed)} "
      elsif @at_most_times_executed
        "at most #{times(@at_most_times_executed)} "
      elsif @expected_times_executed
        "#{times(@expected_times_executed)} "
      else
        is_negated ? "" : "#{times(1)} "
      end
    end

    def times(times)
      "#{times} time#{ (times == 1) ? '' : 's'}"
    end

  end
end
