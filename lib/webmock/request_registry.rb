# frozen_string_literal: true

module WebMock

  class RequestRegistry
    include Singleton

    # Used by #atomically, allocated once rather than on every request.
    DEFER_INTERRUPTS = { Object => :on_blocking }.freeze
    private_constant :DEFER_INTERRUPTS

    attr_accessor :requested_signatures

    def initialize
      @lock = ::Mutex.new
      reset!
    end

    # The counter and the list change together, under one lock, so they
    # always agree.
    def reset!
      atomically do
        @executed_requests = []
        @live_matches = {}
        self.requested_signatures = Util::HashCounter.new
      end
    end

    # Records a request made through an HTTP client adapter. The list holds
    # the copy the counter keeps of each distinct request, so a caller reusing
    # its body buffer cannot change it. A repeated request adds only a
    # reference to that copy, so a suite that never resets keeps one copy of
    # each distinct request.
    def put(request_signature, track_live_matches: false)
      stored = nil
      live_matches = atomically do
        stored = requested_signatures.put(request_signature)
        @executed_requests << stored
        @live_matches
      end
      return unless track_live_matches

      # Matching happens outside the lock. Capture this generation so a
      # concurrent reset cannot attach an old match to a later request.
      lambda do |token, matched|
        @lock.synchronize do
          counts = live_matches[token] ||= {}
          checked, accepted = counts.fetch(stored, [0, 0])
          accepted += 1 if matched
          counts[stored] = [checked + 1, accepted]
        end
      end
    end

    # Every request made since the last reset, in order, repeats included,
    # as copies, so a test cannot change WebMock's records.
    def executed_requests
      requests = @lock.synchronize { @executed_requests.dup }
      copies = {}.compare_by_identity
      requests.map { |request| copies[request] ||= request.dup }.freeze
    end

    def times_executed(request_pattern)
      pattern, conditions = request_pattern.respond_to?(:patterns) ? request_pattern.patterns : [request_pattern]
      base = pattern.is_a?(RequestStub) ? pattern.request_pattern : pattern
      token = base.match_token if base.is_a?(RequestPattern)
      counts, observations = @lock.synchronize { [requested_signatures.snapshot, @live_matches[token]&.dup] }

      counts.sum do |signature, total|
        observed = observations && observations[signature]
        if observed
          # The same snapshot can represent both a stream and a string.
          # Only recheck the requests for which the stub wasn't evaluated.
          checked, accepted = observed
          remaining = total - checked
          accepted += remaining if remaining > 0 && pattern.matches?(signature)
          next 0 if accepted > 0 && conditions && !conditions.matches?(signature)
          accepted
        else
          request_pattern.matches?(signature) ? total : 0
        end
      end
    end

    def to_s
      if requested_signatures.hash.empty?
        "No requests were made."
      else
        text = "".dup
        self.requested_signatures.each do |request_signature, times_executed|
          text << "#{request_signature} was made #{times_executed} time#{times_executed == 1 ? '' : 's' }\n"
        end
        text
      end
    end

    private

    # An interrupt such as Timeout can still stop a thread waiting for the
    # lock, but not one between the two updates, where nothing blocks.
    def atomically(&block)
      Thread.handle_interrupt(DEFER_INTERRUPTS) do
        @lock.synchronize(&block)
      end
    end
  end
end
