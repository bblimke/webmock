module WebMock

  class RequestRegistry
    include Singleton

    attr_accessor :requested_signatures

    def initialize
      reset!
    end

    def reset!
      self.requested_signatures = Util::HashCounter.new
    end

    def times_executed(request_pattern)
      self.requested_signatures.hash.select { |request_signature, times_executed|
        request_pattern.matches?(request_signature)
      }.inject(0) {|sum, (_, times_executed)| sum + times_executed }
    end

  end
end
