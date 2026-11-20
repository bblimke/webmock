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
        self.requested_signatures = Util::HashCounter.new
        @executed_requests = []
      end
    end

    # Records a request made through an HTTP client adapter. The list holds
    # the copy the counter keeps of each distinct request, so a caller reusing
    # its body buffer cannot change it. A repeated request adds only a
    # reference to that copy, so a suite that never resets keeps one copy of
    # each distinct request.
    def put(request_signature)
      atomically do
        @executed_requests << requested_signatures.put(request_signature)
      end
      nil
    end

    # Every request made since the last reset, in order, repeats included,
    # as copies, so a test cannot change WebMock's records.
    def executed_requests
      requests = @lock.synchronize { @executed_requests.dup }
      copies = {}.compare_by_identity
      requests.map { |request| copies[request] ||= request.dup }.freeze
    end

    def times_executed(request_pattern)
      self.requested_signatures.select do |request_signature|
        request_pattern.matches?(request_signature)
      end.inject(0) { |sum, (_, times_executed)| sum + times_executed }
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
