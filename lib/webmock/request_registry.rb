# frozen_string_literal: true

module WebMock

  class RequestRegistry
    include Singleton

    attr_accessor :requested_signatures

    class Request
      attr_accessor :method, :uri, :headers, :body

      def self.from_webmock_request_signature(request_signature)
        new(method: request_signature.method, uri: request_signature.uri, headers: request_signature.headers, body: request_signature.body)
      end

      def initialize(method:, uri:, headers:, body:)
        @method = method
        @uri = uri
        @headers = headers
        @body = body
      end

      def parsed_body
        JSON.parse(body, symbolize_names: true)
      end
    end

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

    def requests_made
      to_a
    end

    def to_a
      requested_signatures.
        array.
        map { |request_signature| Request.from_webmock_request_signature(request_signature) }
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

  end
end
