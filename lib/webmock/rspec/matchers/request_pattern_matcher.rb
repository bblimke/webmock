# frozen_string_literal: true

module WebMock
  class RequestPatternMatcher

    def initialize
      @request_execution_verifier = RequestExecutionVerifier.new
    end

    def once
      @request_execution_verifier.expected_times_executed = 1
      self
    end

    def twice
      @request_execution_verifier.expected_times_executed = 2
      self
    end

    def times(times)
      @request_execution_verifier.expected_times_executed = times.to_i
      self
    end

    def at_least_once
      @request_execution_verifier.at_least_times_executed = 1
      self
    end

    def at_least_twice
      @request_execution_verifier.at_least_times_executed = 2
      self
    end

    def at_least_times(times)
      @request_execution_verifier.at_least_times_executed = times.to_i
      self
    end

    def at_most_once
      @request_execution_verifier.at_most_times_executed = 1
      self
    end

    def at_most_twice
      @request_execution_verifier.at_most_times_executed = 2
      self
    end

    def at_most_times(times)
      @request_execution_verifier.at_most_times_executed = times.to_i
      self
    end

    # Counts only the requests that also match the given conditions, which
    # take the same options and block as RequestPattern#with. Like
    # RequestPattern#with, calling it again adds to the conditions. The stub
    # or request pattern under test is not changed.
    def with(options = {}, &block)
      (@conditions ||= RequestPattern.new(:any, ANY_URI)).with(options, &block)
      self
    end

    def matches?(request_pattern)
      @request_execution_verifier.request_pattern = with_conditions(request_pattern)
      @request_execution_verifier.matches?
    end

    def does_not_match?(request_pattern)
      @request_execution_verifier.request_pattern = with_conditions(request_pattern)
      @request_execution_verifier.does_not_match?
    end

    def failure_message
      @request_execution_verifier.failure_message
    end

    def failure_message_when_negated
      @request_execution_verifier.failure_message_when_negated
    end

    def description
      @request_execution_verifier.description
    end

    # RSpec 2 compatibility:
    alias_method :negative_failure_message, :failure_message_when_negated

    private

    ANY_URI = ->(_uri) { true }
    private_constant :ANY_URI

    # How the description of conditions starts when nothing was given to
    # #with. What was given follows it, as in ' with body "abc"'.
    EMPTY_CONDITIONS = RequestPattern.new(:any, ANY_URI).to_s.freeze
    private_constant :EMPTY_CONDITIONS

    def with_conditions(request_pattern)
      @conditions ? PatternWithConditions.new(request_pattern, @conditions) : request_pattern
    end

    # Matches a request when both the pattern and the conditions match it.
    class PatternWithConditions
      def initialize(pattern, conditions)
        @pattern = pattern
        @conditions = conditions
      end

      # The parts that must all match, so JsonBodyHint can check each of them.
      def patterns
        [@pattern, @conditions]
      end

      def matches?(request_signature)
        @pattern.matches?(request_signature) && @conditions.matches?(request_signature)
      end

      def to_s
        "#{@pattern} (only requests#{@conditions.to_s.delete_prefix(EMPTY_CONDITIONS)})"
      end
    end
    private_constant :PatternWithConditions
  end
end
