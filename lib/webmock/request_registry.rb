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
          begin
            text << "#{request_signature} was made #{times_executed} time#{times_executed == 1 ? '' : 's' }\n"
          rescue Encoding::CompatibilityError => error
            request_signature.body = "ERROR PARSING BODY: " + error.to_s
            text << "#{request_signature} was made #{times_executed} time#{times_executed == 1 ? '' : 's' }\n"
          end
        end
        text
      end
    end

  end
end
